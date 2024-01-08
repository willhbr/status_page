require "./http"
require "http/server/handler"

class StatusPage::HTTPSection
  include Aggregator(Internal::HTTPReqKey, Internal::HTTPReqAgg)
  include HTTP::Handler

  def name
    "HTTP Requests"
  end

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
    key = Internal::HTTPReqKey.new(
      context.request.path,
      context.request.method,
      status
    )
    agg = Internal::HTTPReqAgg.new(
      context.request.content_length.try(&.to_i) || 0,
      resp_size,
      duration,
      start
    )
    self.add_item(key, agg)
    if err = error
      raise err
    end
  end

  include StatusPage::Internal::HTTPRows
end
