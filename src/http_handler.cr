class StatusPage::HTTPSection
  include Section
  include HTTP::Handler

  class ReqInfo
    getter path : String
    getter method : String
    getter request_size : Int32
    getter response_size : Int32
    getter start_time : Time
    getter duration : Time::Span
    getter status : HTTP::Status

    def initialize(@path, @method, @request_size, @response_size, @start_time, @duration, @status)
    end
  end

  def name
    "HTTP Requests"
  end

  @requests = Array(ReqInfo).new

  def call(context)
    start = Time.utc
    error : Exception? = nil
    duration = Time.measure do
      begin
        call_next(context)
      rescue err : Exception
        error = err
      end
    end
    resp_size = 0
    # This is totes not a horrible hack
    if io = context.response.output.as?(HTTP::Server::Response::Output)
      resp_size = io.@out_count
    end
    status = context.response.status
    unless error.nil?
      status = HTTP::Status::INTERNAL_SERVER_ERROR
    end
    info = ReqInfo.new(
      context.request.path, context.request.method,
      context.request.content_length.try(&.to_i) || 0,
      resp_size,
      start,
      duration,
      status
    )
    @requests << info
    if err = error
      raise err
    end
  end

  def render(io : IO)
    html io do
      table do
        header "Path", "Status", "Req bytes", "Resp bytes", "Time", "Duration"
        @requests.each do |req|
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