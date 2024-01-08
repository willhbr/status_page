require "./src/status_page"
require "http/server"

section = StatusPage::HTTPSection.new
section.register!

server = HTTP::Server.new([section, StatusPage.default_handler]) do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end

qs = StatusPage::QuickSection.new "Quick"
qs.register!

client = HTTP::Client::Inspectable.new "willhbr.net"
client.register!
spawn do
  loop do
    resp = client.get("/")
    Log.info { resp }
    sleep 14.seconds
  end
end

Log.setup do |l|
  l.status_page
  l.stderr
end

qs.value("Random") { Random.rand.to_s }

address = server.bind_tcp "0", 80
puts "Listening on http://#{address}"
server.listen
