require "./src/status_page"
require "http/server"

server = HTTP::Server.new([StatusPage.default_handler]) do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end

qs = StatusPage::QuickSection.new "Quick"
qs.register!

Log.setup do |l|
  l.status_page
end

1000.times do |i|
  Log.info { " things #{i}" }
end

qs.value("Random") { Random.rand.to_s }

address = server.bind_tcp "0", 8080
puts "Listening on http://#{address}"
server.listen
