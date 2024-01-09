require "log"

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
end
