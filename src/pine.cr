require "weak_ref"

class Pine::MessageInfo
  include StatusPage::Section

  class RPCInfo
    getter id : UInt32
    getter method : String
    getter request_size : Int32
    getter response_size : Int32 = 0
    getter remote_address : String
    getter connection : WeakRef(Pine::Connection)
    getter start_time = Time.utc
    getter end_time : Time? = nil
    getter status : UInt16 = 0
    getter serialization : String

    def initialize(con, message)
      @connection = WeakRef(Pine::Connection).new(con)
      @id = message.id
      @method = message.method || "unknown!"
      @request_size = message.body.size
      @remote_address = con.remote_address.to_s
      @serialization = con.serializer.name
    end

    def respond(message)
      @end_time = Time.utc
      @response_size = message.body.size
      @status = message.error_code
    end
  end

  alias RPCKey = {UInt32, UInt64}

  @sent_rpcs = Hash(RPCKey, RPCInfo).new
  @recv_rpcs = Hash(RPCKey, RPCInfo).new
  @connections = Set({String, WeakRef(Pine::Connection), Time}).new

  @@instance = new

  def self.instance
    @@instance
  end

  def new_connection(con)
    @connections << {con.remote_address.to_s, WeakRef(Pine::Connection).new(con), Time.utc}
  end

  def incoming(con : Pine::Connection, message : Pine::Message)
    if message.method
      # incoming requests
      @recv_rpcs[{message.id, con.object_id}] = RPCInfo.new(con, message)
    else
      # incoming responses
      if rpc = @sent_rpcs[{message.id, con.object_id}]?
        rpc.respond(message)
      end
    end
  end

  def outgoing(con : Pine::Connection, message : Pine::Message)
    if message.method
      # outgoing requests
      @sent_rpcs[{message.id, con.object_id}] = RPCInfo.new(con, message)
    else
      # outgoing responses
      if rpc = @recv_rpcs[{message.id, con.object_id}]?
        rpc.respond(message)
      end
    end
  end

  def periodic_remove(older_than = 1.day)
    interval = {older_than / 30, 1.minute}.max
    loop do
      sleep interval
      threshold = older_than.ago
      very_old_threshold = (older_than * 3).ago
      @connections = @connections.class.new(@connections.reject { |c| c[1].value.nil? && c[2] < threshold })
      @sent_rpcs = @sent_rpcs.reject { |k, i|
        if e = i.end_time
          e < threshold
        else
          i.start_time < very_old_threshold
        end
      }.to_h
      @recv_rpcs = @recv_rpcs.reject { |k, i|
        if e = i.end_time
          e < threshold
        else
          i.start_time < very_old_threshold
        end
      }.to_h
    end
  end

  def name
    "Pine RPCs"
  end

  def rows_with(t, hash, method)
    now = Time.utc
    t.header "Method", "req bytes", "resp bytes", "Latency", "Status", "Time", "Connection"
    hash.each do |_, rpc|
      next if method && rpc.method != method
      t.row do
        t.th rpc.method
        t.td rpc.request_size.count_bytes
        if fin = rpc.end_time
          t.td rpc.response_size.count_bytes
          t.td fin - rpc.start_time
          t.td rpc.status, class: rpc.status.zero? ? "success" : "failure"
        else
          t.td "-"
          t.td "#{now - rpc.start_time}+"
          t.td "-"
        end
        t.td rpc.start_time

        t.td "#{rpc.remote_address} (#{rpc.serialization})"
      end
    end
  end

  alias StatsKey = {String, UInt16}

  def make_stats(rpcs)
    result = Hash(StatsKey, RPCStats).new
    now = Time.utc
    rpcs.each do |_, rpc|
      key = {rpc.method, rpc.status}
      stats = result[key] ||= RPCStats.new
      stats.count += 1
      stats.total_time += (rpc.end_time || now) - rpc.start_time
      stats.request_total_bytes += rpc.request_size
      stats.response_total_bytes += rpc.response_size
    end
    result
  end

  def stats_rows(t, hash)
    t.header("Method", "Status", "Count", "req bytes", "resp bytes", "Mean latency")
    hash.each do |(method, status), stats|
      t.row do
        t.th method, link: page_url(method: method)
        t.td status, class: status.zero? ? "success" : "failure"
        t.td stats.count

        mean_req = stats.request_total_bytes / stats.count
        mean_resp = stats.response_total_bytes / stats.count
        t.td "#{mean_req.count_bytes} / #{stats.request_total_bytes.count_bytes}"
        t.td "#{mean_resp.count_bytes} / #{stats.response_total_bytes.count_bytes}"

        t.td(stats.total_time / stats.count)
      end
    end
  end

  def render(io : IO)
    received = make_stats(@recv_rpcs)
    sent = make_stats(@sent_rpcs)
    html io do
      table "Received" do
        stats_rows(get_table, received)
      end
      table "Sent" do
        stats_rows(get_table, sent)
      end
      connections_table get_html
    end
  end

  class RPCStats
    property count : UInt32 = 0
    property total_time : Time::Span = 0.seconds
    property request_total_bytes : Int32 = 0
    property response_total_bytes : Int32 = 0
  end

  def render_full(params : HTTP::Params, io : IO)
    method = params["method"]?
    html io do
      table "Received" do
        rows_with get_table, @recv_rpcs, method
      end

      table "Sent" do
        rows_with get_table, @sent_rpcs, method
      end

      connections_table get_html
    end
  end

  def connections_table(html)
    html.table "Connections" do
      header "Remote address", "Connected at", "Connected?", "Services"
      rows @connections do |(addr, con, time)|
        th addr
        td time
        if (connection = con.value) && !connection.closed?
          td "Connected"
          td connection.services.each.map(&.first).join(", ")
        else
          td "Disconnected"
          td "-"
        end
      end
    end
  end
end

module Pine
  class Connection
  end
end

class Pine::Connection::Inspectable < Pine::Connection
  protected def initialize(*args)
    super *args
    Pine::MessageInfo.instance.new_connection self
  end

  def incoming_message(message : Pine::Message)
    Pine::MessageInfo.instance.incoming self, message
    super message
  end

  def outgoing_message(message : Pine::Message)
    Pine::MessageInfo.instance.outgoing self, message
    super message
  end
end
