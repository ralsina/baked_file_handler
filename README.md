# baked_file_handler

A Kemal handler for serving files baked into the application.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     baked_file_handler:
       github: ralsina/baked_file_handler
   ```

2. Run `shards install`

## Usage

```crystal
require "kemal"
require "baked_file_system"

# Example BakedFileSystem class
class MyAssets
  extend BakedFileSystem
  bake_folder "./public_assets"
end

add_handler BakedFileHandler::BakedFileHandler.new(MyAssets)

Kemal.run
```


## Development

I don't expect this need much further development. In any case,
it's simple enough code :-)

## Contributing

1. Fork it (<https://github.com/ralsina/baked_file_handler/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roberto Alsina](https://github.com/ralsina) - creator and maintainer
