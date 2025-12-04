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

## Compression Support

The handler automatically serves compressed versions of files when available and supported by the client.

### How it works:
1. Check the `Accept-Encoding` header for supported compression methods
2. Look for compressed versions of files with `.br` (Brotli) or `.gz` (gzip) extensions
3. Serve the compressed version with appropriate `Content-Encoding` header
4. Fall back to uncompressed files if no compressed version exists

### Priority:
1. Brotli (`.br`) - preferred when client supports it
2. Gzip (`.gz`) - used when client supports gzip but not Brotli
3. Uncompressed - fallback when no compression is supported

### Example:
If you have both `style.css` and `style.css.gz` baked into your assets:
- Request with `Accept-Encoding: gzip` will serve `style.css.gz` with `Content-Encoding: gzip`
- Request with no compression support will serve `style.css` normally


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
