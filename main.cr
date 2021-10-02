require "./src/status_page"

log_catcher = StatusPage::LogSection.new
Log.setup do |l|
  l.bind "*", :debug, log_catcher
  l.bind "*", :debug, Log::IOBackend.new(STDERR)
end

StatusPage::Handler.add_section StatusPage::ProgramInfo.new
StatusPage::Handler.add_section log_catcher
http = StatusPage::HTTPSection.new
StatusPage::Handler.add_section http

server = HTTP::Server.new [http, StatusPage::Handler.handler] do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
  Log.debug { context.request }
end

address = server.bind_tcp "0", 8080
Log.debug { "Listening on http://#{address}" }
server.listen
