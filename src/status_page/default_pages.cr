require "geode"
require "./section"
require "json"

class Log::Builder
  def status_page(severity = Severity::Info, match = "*", skip_add = false,
                  capacity = 1000, preview_display = 30)
    backend = StatusPage::LogSection.new(capacity: capacity, preview_display: preview_display)
    backend.register! unless skip_add
    self.bind(match, severity, backend)
    backend
  end
end

module StatusPage
  class LogSection < Log::Backend
    include Section

    def initialize(capacity = 1000, @preview_display = 20)
      super(Log::DispatchMode::Sync)
      @buffer = Geode::CircularBuffer(Log::Entry).new capacity
      @lock = Mutex.new
    end

    def write(entry)
      @lock.synchronize do
        @buffer.push entry
      end
    end

    def name
      "Logs"
    end

    def render_full(params : HTTP::Params, io : IO)
      render_internal(io, limit: @buffer.size)
    end

    def render(io : IO)
      render_internal(io, limit: @preview_display)
    end

    private def render_internal(io : IO, limit)
      html io do
        div class: "mono" do
          table do
            @lock.synchronize do
              @buffer.each_last(limit) do |entry|
                row class: entry.severity.to_s.downcase do
                  td Time::Format::ISO_8601_DATE_TIME.format(entry.timestamp)
                  td entry.severity
                  if exception = entry.exception
                    td "#{entry.message}\n#{exception.inspect_with_backtrace}"
                  else
                    td entry.message
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  struct ProgramInfo
    include Section

    BUILT_ON   = Time.unix({{ `date +%s`.strip + "_i64" }})
    STARTED_AT = Time.utc
    BUILT_BY   = {{ env("USER") }}
    BUILD_HOST = {{ `hostname`.stringify }}
    RUNNING_AS = `whoami`.strip
    HOST_OS    = self.host_os
    ARGS       = ARGV

    def self.host_os
      File.open("/etc/os-release") do |file|
        while line = file.gets
          if line.starts_with? "PRETTY_NAME="
            value = line.lchop "PRETTY_NAME="
            return String.from_json(value)
          end
        end
      end
      return "unknown"
    end

    def self.to_s(io)
      {% begin %}
        {% for c in @type.constants %}
          io << {{ c.stringify }} << " = " << {{ c }} << '\n'
        {% end %}
      {% end %}
    end

    def name
      "Program"
    end

    def render(io : IO)
      html io do
        div class: "mono" do
          escape PROGRAM_NAME, " "
          ARGS.each do |arg|
            escape Process.quote(arg), " "
          end
        end
        table do
          kv "Built:", "at #{BUILT_ON} (#{Time.utc - BUILT_ON} ago) (Crystal #{Crystal::VERSION}) by #{BUILT_BY} on #{BUILD_HOST}"
          kv "Started at:", "#{STARTED_AT} (up #{Time.utc - STARTED_AT})"
          kv "Running as:", "#{RUNNING_AS} on #{System.hostname} (#{HOST_OS})"
          stats = GC.stats
          kv "GC:", "Free: #{stats.free_bytes.count_bytes}, total: #{stats.total_bytes.count_bytes}, since GC: #{stats.bytes_since_gc.count_bytes}"
          kv "Load avg: ", File.read("/proc/loadavg")
        end
      end
    end
  end
end
