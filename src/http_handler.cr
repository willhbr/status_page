class StatusPage::HTTPSection
  include Section
  include HTTP::Handler

  def name
    "HTTP Requests"
  end

  class RequestInfo
    property count : UInt32 = 0
    property mean_latency_ms : Float32 = 0.0
  end

  @requests = Hash({String, HTTP::Status}, RequestInfo).new { |h, k| h[k] = RequestInfo.new }

  def call(context)
    latency = Time.measure do
      call_next(context)
    end
    status = context.response.status
    info = @requests[{context.request.path, status}]
    info.count += 1
    info.mean_latency_ms = (info.mean_latency_ms * (info.count - 1) + latency.milliseconds) / info.count
  end

  def render(io : IO)
    html io do
      table do
        row do
          th "Path"
          th "Status"
          th "Count"
          th "Mean Latency"
        end
        @requests.each do |(path, status), info|
          row do
            th path
            td status
            td info.count
            td info.mean_latency_ms
          end
        end
      end
    end
  end
end
