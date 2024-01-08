module StatusPage::Internal
  record HTTPReqKey, path : String, method : String, status : HTTP::Status do
    def <=>(other)
      @path <=> other.path
    end
  end

  struct HTTPReqAgg
    property request_size : Int32
    property response_size : Int32
    property duration : Time::Span
    property time : Time
    property count : Int32

    def initialize(@request_size, @response_size, @duration, @time)
      @count = 1
    end

    def +(other : HTTPReqAgg)
      @request_size += other.request_size
      @response_size += other.response_size
      @duration += other.duration
      @count += other.count
      @time = {@time, other.time}.max
      self
    end

    def <=>(other)
      @time <=> other.time
    end
  end

  module HTTPRows
    def aggregated_header(t : StatusPage::HTMLBuilder::Table)
      t.row do
        t.th "Count"
        t.th "Method"
        t.th "Path"
        t.th "Status"
        t.th "Request Size"
        t.th "Response Size"
        t.th "Latency"
        t.th "Latest"
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
        t.td "#{agg.time} (#{Time.utc - agg.time} ago)"
      end
    end

    def item_header(t : StatusPage::HTMLBuilder::Table)
      t.row do
        t.th "Path"
        t.th "Status"
        t.th "Request Size"
        t.th "Response Size"
        t.th "Latency"
        t.th "Time"
      end
    end

    def item_row(t : StatusPage::HTMLBuilder::Table, key : HTTPReqKey, agg : HTTPReqAgg)
      t.row do
        t.th "#{key.method}: #{key.path}"
        t.td "#{key.status} (#{key.status.code})"
        t.td agg.request_size.count_bytes
        t.td agg.response_size.count_bytes
        t.td agg.duration
        t.td "#{agg.time} (#{Time.utc - agg.time} ago)"
      end
    end
  end
end
