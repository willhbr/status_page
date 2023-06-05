class StatusPage::HTTPReqInfo
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
