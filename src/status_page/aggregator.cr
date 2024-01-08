require "./section"

module Aggregator(K, A)
  include StatusPage::Section
  @items = Geode::CircularBuffer(Tuple(K, A)).new(500)
  @aggregated = Hash(K, A).new

  def add_item(key : K, agg : A)
    if existing = @aggregated[key]?
      @aggregated[key] = agg + existing
    else
      @aggregated[key] = agg
    end
    @items << {key, agg}
  end

  abstract def aggregated_header(t : StatusPage::HTMLBuilder::Table)
  abstract def aggregated_row(t : StatusPage::HTMLBuilder::Table, key : K, agg : A)
  abstract def item_header(t : StatusPage::HTMLBuilder::Table)
  abstract def item_row(t : StatusPage::HTMLBuilder::Table, key : K, agg : A)

  def filter_link(t, content, **params)
    t.link(self.page_url(**params)) do
      t.escape content
    end
  end

  def render(io : IO)
    html io do
      table do
        self.aggregated_header(get_table)
        @aggregated.to_a.sort_by { |i| {i[0], i[1]} }.each do |key, agg|
          self.aggregated_row(get_table, key, agg)
        end
      end
    end
  end

  def render_full(params : HTTP::Params, io : IO)
    html io do
      {% for var in K.instance_vars %}
        {{ var }}_filter = params[{{ var.stringify }}]?
      {% end %}
      filters = String.build do |io|
        first = true
        {% for var in K.instance_vars %}
          if f = {{ var }}_filter
            unless first
              io << ", "
              first = false
            end
            io << {{ var.stringify }} << "=" << HTML.escape(f)
          end
        {% end %}
      end
      table filters do
        self.item_header(get_table)
        @items.each do |item|
          key, agg = item
          {% for var in K.instance_vars %}
            if f = {{ var }}_filter
              next if key.{{ var }}.to_s != f
            end
          {% end %}
          self.item_row(get_table, key, agg)
        end
      end
    end
  end
end
