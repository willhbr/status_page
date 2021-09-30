module StatusPage
  class LogSection < Log::Backend
    include Section

    def initialize(size = 1000)
      super(Log::DispatchMode::Sync)
      @messages = Deque(Log::Entry).new size
    end

    def write(entry)
      @messages.push entry
    end

    def name
      "Logs"
    end

    def render(io : IO)
      html io do
        div class: "mono" do
          table do
            @messages.each do |entry|
              row class: entry.severity.to_s.downcase do
                td Time::Format::ISO_8601_DATE_TIME.format(entry.timestamp)
                td entry.message
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
          ARGV.each do |arg|
            escape Process.quote(arg), " "
          end
        end
        table do
          kv "Built:", "at #{ProgramInfo::BUILT_ON} (Crystal #{Crystal::VERSION}) by #{ProgramInfo::BUILT_BY} on #{ProgramInfo::BUILD_HOST}"
          kv "Started at:", "#{ProgramInfo::STARTED_AT} (up #{Time.utc - ProgramInfo::STARTED_AT})"
        end
      end
    end
  end
end
