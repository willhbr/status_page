require "http/client"
require "geode"
require "./http"

class IOCounter < IO
  getter read_size
  getter write_size

  def initialize(@wrapped : IO)
    @read_size = 0
    @write_size = 0
  end

  def reset
    @read_size = 0
    @write_size = 0
  end

  def read(slice : Bytes) : Int32
    size = @wrapped.read(slice)
    @read_size += size
    size
  end

  def write(slice : Bytes) : Nil
    @wrapped.write(slice)
    @write_size += slice.size
  end
end

# TODO split this into a status section that can handle multiple clients
class HTTP::Client::Inspectable < HTTP::Client
  include StatusPage::Section
  @requests = Geode::CircularBuffer(StatusPage::HTTPReqInfo).new(200)

  class TCPSocket
    def self.new(*args)
      sock = ::TCPSocket.new(*args)
      IOCounter.new(sock)
    end
  end

  def name
    "HTTP::Client #{@host}:#{@port}"
  end

  def exec(request : HTTP::Request) : HTTP::Client::Response
    start = Time.utc
    error : Exception? = nil
    unless io = @io.as? IOCounter
      @io = io = IOCounter.new(self.io)
    end
    io.reset
    response = super(request)
    duration = Time.utc - start
    # TODO fix
    resp_size = 0
    status = response.status
    info = StatusPage::HTTPReqInfo.new(
      request.path, request.method,
      io.write_size,
      resp_size,
      start,
      duration,
      status
    )
    @requests << info
    response
  end

  def render(io : IO)
    render_internal(io, 20)
  end

  def render_full(params : HTTP::Params, io : IO)
    render_internal(io, @requests.size)
  end

  def render_internal(io, count)
    html io do
      table do
        header "Path", "Status", "Req bytes", "Resp bytes", "Time", "Duration"
        @requests.each_last(count) do |req|
          row do
            th "#{req.method}: #{req.path}"
            td "#{req.status} (#{req.status.code})"
            td req.request_size.count_bytes
            td req.response_size.count_bytes
            td req.start_time
            td req.duration
          end
        end
      end
    end
  end
end
