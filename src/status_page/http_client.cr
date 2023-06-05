require "http/client"
require "geode"
require "./http"

class HTTP::Client::Inspectable < HTTP::Client
  include StatusPage::Section
  @requests = Geode::CircularBuffer(StatusPage::HTTPReqInfo).new(200)

  def name
    "HTTP::Client #{@host}:#{@port}"
  end

  def exec(request : HTTP::Request) : HTTP::Client::Response
    start = Time.utc
    error : Exception? = nil
    response : HTTP::Client::Response? = nil
    Log.info { request }
    response = super(request)
    duration = Time.utc - start
    # TODO fix
    resp_size = 0
    status = response.status
    info = StatusPage::HTTPReqInfo.new(
      request.path, request.method,
      request.content_length.try(&.to_i) || 0,
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
