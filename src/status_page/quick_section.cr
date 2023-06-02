require "./section"
require "./html_builder"

module StatusPage
  class QuickSection
    include StatusPage::Section

    getter name : String

    def initialize(@name)
      @values = Hash(String, Proc(String)).new
    end

    def value(name, &block : Proc(String))
      @values[name] = block
    end

    class Counter
      getter value : Int32

      def initialize(@value)
      end

      def inc(by : Int32 = 1)
        @value += by
      end
    end

    def counter(name, initial_value = 0)
      cnt = Counter.new(initial_value)
      value(name) { cnt.value.to_s }
      cnt
    end

    def render(io : IO)
      html io do
        table do
          @values.each do |name, provider|
            row do
              th name
              td provider.call
            end
          end
        end
      end
    end
  end
end
