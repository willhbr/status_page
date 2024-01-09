require "http"
require "log"
require "ecr"

require "./status_page/*"

module StatusPage
  @@instance : Handler? = nil

  def self.default_handler
    @@instance ||= StatusPage::Handler.new("/status")
  end

  def self.make_server(
    handlers = [] of HTTP::Handler,
    no_http = false,
    &block : Proc(HTTP::Server::Context, Nil)
  )
    h = [] of HTTP::Handler
    unless no_http
      http = StatusPage::HTTPSection.new
      http.register!
      h << http
    end
    h << StatusPage.default_handler
    h.concat(handlers)

    HTTP::Server.new h do |context|
      block.call context
    end
  end

  def self.make_server(
    handlers = [] of HTTP::Handler,
    no_http = false
  )
    make_server(handlers, no_http) do |context|
      context.response.status = HTTP::Status::NOT_FOUND
    end
  end
end
