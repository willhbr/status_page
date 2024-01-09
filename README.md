# Status Page

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     status_page:
       github: willhbr/status_page
   ```

2. Run `shards install`

## Usage

```crystal
require "status_page"

server = StatusPage.make_server(MyHTTPHandler.new) do |context|
  # your server logic here if you want
end
```

## Contributing

1. Fork it (<https://github.com/willhbr/status_page/fork>)
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create a new Pull Request
