require "http/client"
require "geode"
require "./http"

# TODO split this into a status section that can handle multiple clients
class HTTP::Client::Inspectable < HTTP::Client
  include Aggregator(StatusPage::Internal::HTTPReqKey, StatusPage::Internal::HTTPReqAgg)

  def name
    "HTTP::Client #{@host}:#{@port}"
  end

  def exec(request : HTTP::Request) : HTTP::Client::Response
    start = Time.utc
    error : Exception? = nil
    begin
      response = super(request)
    rescue ex
      error = ex
    end
    duration = Time.utc - start
    resp_size = 0
    if response
      status = response.status
      resp_size = response.headers["Content-Length"].to_i
    else
      status = HTTP::Status::INTERNAL_SERVER_ERROR
    end

    key = StatusPage::Internal::HTTPReqKey.new(
      request.path,
      request.method,
      status
    )
    agg = StatusPage::Internal::HTTPReqAgg.new(
      request.content_length.try(&.to_i) || 0,
      resp_size,
      duration,
      start
    )
    self.add_item(key, agg)
    if error
      raise error
    end
    response.not_nil!
  end

  include StatusPage::Internal::HTTPRows
end
