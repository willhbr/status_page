require "geode"

class Log::Builder
  def status_page(severity = Severity::Info, match = "*", skip_add = false)
    backend = StatusPage::LogSection.new
    StatusPage::Handler.add_section backend unless skip_add
    self.bind(match, severity, backend)
    backend
  end
end

module StatusPage
  class LogSection < Log::Backend
    include Section

    def initialize(capacity = 1000)
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

    def render(io : IO)
      html io do
        div class: "mono" do
          table do
            @lock.synchronize do
              @buffer.each do |entry|
                row class: entry.severity.to_s.downcase do
                  td Time::Format::ISO_8601_DATE_TIME.format(entry.timestamp)
                  td entry.severity
                  td entry.message
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
    ARGS       = ARGV

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
          kv "Running as:", "#{RUNNING_AS} on #{System.hostname}"
          stats = GC.stats
          kv "GC:", "Free: #{stats.free_bytes.count_bytes}, total: #{stats.total_bytes.count_bytes}, since GC: #{stats.bytes_since_gc.count_bytes}"
          kv "Load avg: ", File.read("/proc/loadavg")
        end
      end
    end
  end
end
