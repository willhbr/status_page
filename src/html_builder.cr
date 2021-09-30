struct StatusPage::HTMLBuilder
  struct Table
    def initialize(@io : IO)
    end

    def row(**args)
      @io << "<tr"
      args.each do |k, v|
        @io << ' ' << k << "=\"" << HTML.escape(v) << '"'
      end
      @io << '>'
      yield
      @io << "</tr>"
    end

    def kv(key, value, **args)
      row **args do
        th key
        td value
      end
    end

    {% for tag in {:td, :th} %}
      def {{ tag.id }}(**args)
        @io << "<{{ tag.id }}"
        args.each do |k, v|
          @io << ' ' << k << "=\"" << HTML.escape(v) << '"'
        end
        @io << '>'
        yield
        @io << "</{{ tag.id }}>"
      end

      def {{ tag.id }}(content, **args)
        {{ tag.id }}(**args) { @io << HTML.escape(content) }
      end
    {% end %}
  end

  def initialize(@io : IO)
  end

  def escape(*output)
    output.each do |o|
      @io << HTML.escape o
    end
  end

  def div(**args)
    @io << "<div"
    args.each do |k, v|
      @io << ' ' << k << "=\"" << HTML.escape(v) << '"'
    end
    @io << '>'
    yield
    @io << "</div>"
  end

  def table(name : String? = nil, &block)
    @io << "<table>"
    if n = name
      @io << "<caption>" << HTML.escape(n) << "</caption>"
    end
    with Table.new(@io) yield
    @io << "</table>"
  end
end
