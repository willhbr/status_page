require "./html_builder"

module StatusPage
  module Section
    def name : String
      {{ @type.name.stringify }}
    end

    def html(io : IO)
      with HTMLBuilder.new(io) yield
    end

    abstract def render(io : IO)

    def render_full(io : IO)
      render(io)
    end
  end
end
