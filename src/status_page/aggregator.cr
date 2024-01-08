require "./section"

abstract class Aggregator(K, A)
  include StatusPage::Section
  @items : Geode::CircularBuffer(Tuple(K, A))
  @aggregated = Hash(K, A).new

  def initialize(capacity)
    @items = Geode::CircularBuffer(Tuple(K, A)).new(capacity)
  end

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
        @aggregated.to_a.sort_by { |i| i[0] }.each do |key, agg|
          self.aggregated_row(get_table, key, agg)
        end
      end
    end
  end

  def render_full(params : HTTP::Params, io : IO)
    html io do
      table do
        self.item_header(get_table)
        {% for var in K.instance_vars %}
          {{ var }}_filter = params[{{ var.stringify }}]?
        {% end %}
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
