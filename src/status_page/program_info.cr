require "geode"
require "./section"
require "json"

module StatusPage
  struct ProgramInfo
    include Section

    BUILT_ON   = Time.unix({{ `date +%s`.strip + "_i64" }})
    STARTED_AT = Time.utc
    BUILT_BY   = {{ env("USER") }}
    BUILD_HOST = {{ `hostname`.stringify }}
    RUNNING_AS = `whoami`.strip
    HOST_OS    = self.host_os
    ARGS       = ARGV
    COMMIT     = {{ `sh -c '[ -e .git/HEAD ] && head -c 7 .git/HEAD' || echo 'unknown'`.stringify }}

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
          kv "Build commit", COMMIT
        end
      end
    end
  end
end
