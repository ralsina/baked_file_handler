# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Crystal shard that provides a `BakedFileHandler` for Kemal web applications. It serves files that are "baked" (embedded) directly into the application binary using Crystal's `BakedFileSystem` system, allowing single-binary deployments with embedded static assets.

## Development Commands

### Building and Testing
```bash
# Build the project (no --release flag per development guidelines)
shards build

# Run tests
crystal spec

# Install dependencies
shards install

# Run with specific test file
crystal spec spec/baked_file_handler_spec.cr
```

### Linting and Code Quality
```bash
# Format code using Crystal's built-in formatter
crystal tool format

# Use ameba for linting if available (follow patterns from dependencies)
# Check for useless assignments and not_nil! usage
```

- Follow Crystal standard conventions (2-space indentation, LF line endings)
- Code style is enforced by `.editorconfig`
- Prefer descriptive parameter names over single letters
- Avoid `not_nil!` usage (follow dependency patterns)

### Version Management
- Current version: 0.1.3 (in shard.yml)
- VERSION constant in src/baked_file_handler.cr should match

## Architecture

### Core Components
- **`BakedFileHandler` class** (`src/baked_file_handler.cr`): Main handler that extends `Kemal::StaticFileHandler`
- **Dependency Injection**: Takes a `BakedFileSystem` class in constructor
- **Handler Chain**: Integrates with Kemal's middleware stack via `HTTP::Handler`
- **Compression Support**: Automatic Brotli (.br) and gzip (.gz) file serving

### Key Design Patterns
1. **Single-class architecture** - All functionality in one class (~207 lines)
2. **Fallback strategy** - Uses `fallthrough` pattern to pass requests to next handler if file not found
3. **Memory-based serving** - Serves files directly from embedded filesystem, not disk
4. **HTTP compliance** - Proper handling of GET/HEAD methods, status codes, and headers
5. **Compression-first** - Checks for compressed versions (.br, .gz) before uncompressed

### Request Flow
1. HTTP request enters via `call(context)` method
2. Validates method (GET/HEAD only, others fall through)
3. Converts request path to baked filesystem key using `Path.posix(URI.decode(request_path)).relative_to("/").to_s`
4. Checks `Accept-Encoding` header for compression support
5. Attempts compressed file serve (.br then .gz) if supported
6. Falls back to uncompressed file via `serve_baked_key`
7. If configured, tries `index.html` for directory-like paths
8. Falls through to next handler if no match found

### Integration Pattern
```crystal
# User code creates a BakedFileSystem class
class MyAssets
  extend BakedFileSystem
  bake_folder "./public_assets"
end

# Add handler to Kemal app
add_handler BakedFileHandler::BakedFileHandler.new(MyAssets)
```

## Important Implementation Details

- **Resource Management**: Uses `ensure` blocks for proper IO cleanup with `io.try &.close`
- **Error Handling**: Comprehensive exception handling with fallback responses and logging
- **MIME Types**: Automatically sets Content-Type based on file extension using `MIME.from_extension?`
- **Caching**: Configurable Cache-Control headers (defaults to "max-age=604800" - 1 week)
- **Method Safety**: Only serves GET and HEAD requests for security
- **Compression**: Transparent compression support with proper Content-Encoding headers
- **Logging**: Uses `Log.for(self)` for debug and error logging

### Configuration Options
- `fallthrough`: Whether to pass unmatched requests to next handler (default: true)
- `serve_index_html`: Whether to serve index.html for directory paths (default: true)
- `cache_control`: Cache-Control header value (default: 1 week)

## Testing

- Tests are in `spec/` directory
- Uses Crystal's built-in `spec` framework
- Test setup in `spec/spec_helper.cr` (requires kemal and baked_file_handler)
- Current test coverage is minimal - basic instantiation and version tests only
- Test pattern uses `TestFS` class extending `BakedFileSystem` for testing