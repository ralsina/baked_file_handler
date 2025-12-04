# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Crystal shard that provides a `BakedFileHandler` for Kemal web applications. It serves files that are "baked" (embedded) directly into the application binary using Crystal's `BakedFileSystem` system, allowing single-binary deployments with embedded static assets.

## Development Commands

### Building and Testing
```bash
# Build the project
shards build

# Run tests
crystal spec

# Install dependencies
shards install

# Run with specific test file
crystal spec spec/baked_file_handler_spec.cr
```

### Linting and Code Quality
- The project uses Crystal's built-in formatter
- No explicit linting configuration found - follow standard Crystal conventions
- Run `crystal tool format` to format code before committing

## Architecture

### Core Components
- **`BakedFileHandler` class** (`src/baked_file_handler.cr`): Main handler that extends `Kemal::StaticFileHandler`
- **Dependency Injection**: Takes a `BakedFileSystem` class in constructor
- **Handler Chain**: Integrates with Kemal's middleware stack via `HTTP::Handler`

### Key Design Patterns
1. **Single-class architecture** - All functionality in one 166-line class
2. **Fallback strategy** - Uses `fallthrough` pattern to pass requests to next handler if file not found
3. **Memory-based serving** - Serves files directly from embedded filesystem, not disk
4. **HTTP compliance** - Proper handling of GET/HEAD methods, status codes, and headers

### Request Flow
1. HTTP request enters via `call(context)` method
2. Validates method (GET/HEAD only, others fall through)
3. Converts request path to baked filesystem key using `Path.posix(...).relative_to("/").to_s`
4. Attempts direct file serve via `serve_baked_key`
5. If configured, tries `index.html` for directory-like paths
6. Falls through to next handler if no match found

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

- **Resource Management**: Uses `ensure` blocks for proper IO cleanup
- **Error Handling**: Comprehensive exception handling with fallback responses
- **MIME Types**: Automatically sets Content-Type based on file extension
- **Caching**: Configurable Cache-Control headers (defaults to 1 week)
- **Method Safety**: Only serves GET and HEAD requests for security

## Testing

- Tests are in `spec/` directory
- Uses Crystal's built-in `spec` framework
- Test setup in `spec/spec_helper.cr`
- Current test coverage is minimal - main spec file exists but needs implementation