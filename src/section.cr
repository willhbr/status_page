require "./html_builder"

module StatusPage
  module Section
    def name : String
      {{ @type.name.stringify }}
    end

    def page_url(**params)
      String.build do |io|
        io << "status?view=" << self.class.name
        params.each do |name, value|
          io << '&' << name << '=' << URI.encode(value)
        end
      end
    end

    def html(io : IO)
      with HTMLBuilder.new(io) yield
    end

    abstract def render(io : IO)

    def render_full(params : HTTP::Params, io : IO)
      render(io)
    end
  end
end
