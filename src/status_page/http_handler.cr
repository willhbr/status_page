require "./http"
require "http/server/handler"

class StatusPage::HTTPReqInfo
  getter path : String
  getter method : String
  getter status : HTTP::Status
  getter start_time : Time
  getter request_size : Int32
  getter response_size : Int32
  getter duration : Time::Span

  def initialize(@path, @method, @request_size, @response_size, @start_time, @duration, @status)
  end
end

record HTTPReqKey, path : String, method : String, status : HTTP::Status do
  def <=>(other)
    @path <=> other.path
  end
end

struct HTTPReqAgg
  property request_size : Int32
  property response_size : Int32
  property duration : Time::Span
  property count : Int32

  def initialize(@request_size, @response_size, @duration)
    @count = 0
  end

  def +(other : HTTPReqAgg)
    @request_size += other.request_size
    @response_size += other.response_size
    @duration += other.duration
    @count += other.count
    self
  end
end

class StatusPage::HTTPSection < Aggregator(HTTPReqKey, HTTPReqAgg)
  include HTTP::Handler

  def initialize
    super 500
  end

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
    key = HTTPReqKey.new(
      context.request.path,
      context.request.method,
      status
    )
    agg = HTTPReqAgg.new(
      context.request.content_length.try(&.to_i) || 0,
      resp_size,
      duration
    )
    self.add_item(key, agg)
    if err = error
      raise err
    end
  end

  def aggregated_header(t : StatusPage::HTMLBuilder::Table)
    t.row do
      t.th "Count"
      t.th "Method"
      t.th "Path"
      t.th "Status"
      t.th "Request Size"
      t.th "Response Size"
      t.th "Latency"
    end
  end

  def aggregated_row(
    t : StatusPage::HTMLBuilder::Table,
    key : HTTPReqKey, agg : HTTPReqAgg
  )
    t.row do
      t.td agg.count
      t.th do
        self.filter_link(t, key.method, method: key.method)
      end
      t.th do
        self.filter_link(t, key.path, path: key.path)
      end
      t.td { self.filter_link(t, "#{key.status} (#{key.status.code})", status: key.status.to_s) }
      mean_req = (agg.request_size / agg.count)
      mean_resp = (agg.response_size / agg.count)
      t.td "#{mean_req.count_bytes} / #{agg.request_size.count_bytes}"
      t.td "#{mean_resp.count_bytes} / #{agg.response_size.count_bytes}"
      t.td(agg.duration / agg.count)
    end
  end

  def item_header(t : StatusPage::HTMLBuilder::Table)
    t.row do
      t.th "Path"
      t.th "Status"
      t.th "Request Size"
      t.th "Response Size"
      t.th "Latency"
    end
  end

  def item_row(t : StatusPage::HTMLBuilder::Table, key : HTTPReqKey, agg : HTTPReqAgg)
    t.row do
      t.th "#{key.method}: #{key.path}"
      t.td "#{key.status} (#{key.status.code})"
      t.td agg.request_size.count_bytes
      t.td agg.response_size.count_bytes
      t.td agg.duration
    end
  end
end
