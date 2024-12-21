struct StatusPage::HTMLBuilder
  module HTMLNodes
    def escape(*output)
      output.each do |o|
        @io << HTML.escape o
      end
    end

    def node(name, **args)
      @io << "<#{name}"
      args.each do |k, v|
        @io << ' ' << k << "=\"" << HTML.escape(v) << '"'
      end
      @io << '>'
      yield
      @io << "</#{name}>"
    end

    def div(**args)
      node "div", **args do
        yield
      end
    end

    def pre(**args)
      node "pre", **args do
        yield
      end
    end

    def link(href : String)
      @io << "<a href=\"" << HTML.escape(href) << "\">"
      yield
      @io << "</a>"
    end

    def link(content, href : String)
      link href { escape content }
    end
  end

  struct Table
    include HTMLNodes

    def initialize(@io : IO)
    end

    def row(**args)
      @io << "<tr"
      args.each do |k, v|
        @io << ' ' << k << "=\"" << HTML.escape(v.to_s) << '"'
      end
      @io << '>'
      yield
      @io << "</tr>"
    end

    def header(*titles)
      row do
        titles.each do |title|
          th title
        end
      end
    end

    def rows(iter, **args)
      iter.each do |item|
        row **args do
          yield item
        end
      end
    end

    def kv(key, value, **args)
      row **args do
        th key
        td value
      end
    end

    def link(href : String)
      @io << "<a href=\"" << HTML.escape(href) << "\">"
      yield
      @io << "</a>"
    end

    def link(content, href : String)
      link(href) do
        escape content
      end
    end

    def escape(*output)
      output.each do |o|
        @io << HTML.escape o
      end
    end

    {% for tag in {:td, :th} %}
      def {{ tag.id }}(link : String? = nil, **args)
        @io << "<{{ tag.id }}"
        args.each do |k, v|
          @io << ' ' << k << "=\"" << HTML.escape(v.to_s) << '"'
        end
        @io << '>'
        if l = link
          link(href: l) { yield }
        else
          yield
        end
        @io << "</{{ tag.id }}>"
      end

      def {{ tag.id }}(content, **args)
        {{ tag.id }}(**args) { @io << HTML.escape(content.to_s) }
      end
    {% end %}

    def get_table
      self
    end
  end

  include HTMLNodes

  def initialize(@io : IO)
  end

  def get_html
    self
  end

  def table(name : String? = nil, **args, &block)
    @io << "<table"
    args.each do |k, v|
      @io << ' ' << k << "=\"" << HTML.escape(v.to_s) << '"'
    end
    @io << '>'
    if n = name
      @io << "<caption>" << HTML.escape(n) << "</caption>"
    end
    with Table.new(@io) yield
    @io << "</table>"
  end
end
