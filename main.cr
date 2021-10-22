require "./src/status_page"

Log.setup do |l|
  l.status_page Log::Severity::Debug
  l.stderr
end

http = StatusPage::HTTPSection.new
http.register!

server = HTTP::Server.new [http, StatusPage::Handler.handler] do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
  Log.debug { context.request }
end

spawn do
  loop do
    sleep 3.seconds
    Log.debug { "Doing stuff..." }
  end
end

address = server.bind_tcp "0", 8080
Log.debug { "Listening on http://#{address}" }
server.listen
