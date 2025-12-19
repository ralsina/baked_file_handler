require "baked_file_system"

module BakedFileHandler
  VERSION = "0.1.4"

  # # BakedFileHandler
  #
  # `BakedFileHandler` is a specialized `HTTP::Handler` designed to serve
  # files embedded within the application binary using a `BakedFileSystem`
  # compatible class.
  #
  # It replaces standard filesystem lookups with lookups in the provided
  # baked assets class. This allows serving static content (HTML, CSS, JS,
  # images, etc.) directly from memory, making the application distributable
  # as a single binary without loose asset files.
  #
  # ## Features:
  # - Serves files from a `BakedFileSystem` class.
  # - Handles GET and HEAD requests.
  # - Optionally serves `index.html` for directory-like paths (e.g., `/admin/` serves `/admin/index.html`).
  # - Sets `Content-Type` based on file extension.
  # - Allows configuring `Cache-Control` headers.
  # - Fallthrough to the next handler if a file is not found or the method is not supported.
  # - Optional mount path support for improved performance in busy applications.
  #
  # ## Usage:
  #
  # ```
  # require "kemal"
  # require "baked_file_system"
  #
  # # Example BakedFileSystem class
  # class MyAssets
  #   extend BakedFileSystem
  #   bake_folder "./public_assets"
  # end
  #
  # # In your Kemal app:
  # baked_asset_handler = BakedFileHandler.new(
  #   MyAssets)
  # add_handler baked_asset_handler
  #
  # Kemal.run
  # ```
  #
  # When a request like `GET /css/style.css` is received, `BakedFileHandler`
  # will attempt to retrieve and serve the file associated with the key
  # `"/css/style.css"` from the `MyAssets` class.
  #
  # ## Caveats:
  # - Directory listing is not supported.
  # - File modification times and ETag based on `mtime` are not used for caching,
  #   as baked assets are immutable at runtime. Caching relies on `Cache-Control`.
  # - Range requests are not explicitly supported by this handler;
  #   the entire file content is served.

  class BakedFileHandler < Kemal::StaticFileHandler
    Log = ::Log.for(self)

    @baked_fs_class : BakedFileSystem
    @serve_index_html : Bool = true
    @cache_control : String? = "max-age=604800" # Default 1 week
    @mount_path : String

    # Creates a new `BakedFileHandler`.
    #
    # Arguments:
    #   - `baked_fs_class`: The class object (e.g., `MyAssets`) that extends `BakedFileSystem`
    #     and contains the baked files.
    #   - `fallthrough`: If `true` (default), calls the next handler if a file is not found
    #     or if the request method is not GET or HEAD. (Passed to `super`)
    #   - `serve_index_html`: If `true` (default), attempts to serve `index.html` for
    #     requests to directory-like paths (e.g., `/admin/` serves `/admin/index.html`).
    #   - `cache_control`: Sets the `Cache-Control` header for successful responses.
    #     Defaults to "max-age=604800" (1 week). Set to `nil` to omit this header.
    #   - `mount_path`: The path where this handler should be mounted. Defaults to "/".
    #     When set to a specific path (e.g., "/assets"), the handler will only process
    #     requests that start with that path, improving performance in busy applications.
    def initialize(
      @baked_fs_class : BakedFileSystem,
      fallthrough = true,
      @serve_index_html = true,
      @cache_control = "max-age=604800",
      mount_path = "/",
    )
      @mount_path = mount_path.ends_with?("/") ? mount_path : "#{mount_path}/"
      # Call super with the mount_path, as we override `call` and don't use parent's fs logic.
      # Parent's directory_listing is also made false as we don't support it.
      super(@mount_path, fallthrough, directory_listing: false)
    end

    # Overrides the main request handling method from `HTTP::StaticFileHandler`.
    # This implementation bypasses filesystem checks and serves directly from
    # the `BakedFileSystem`.
    def call(context : HTTP::Server::Context)
      request_path = context.request.path

      # Skip processing if request doesn't start with mount_path (unless root mount)
      if @mount_path != "/" && !request_path.starts_with?(@mount_path)
        return call_next(context)
      end

      unless ["GET", "HEAD"].includes? context.request.method
        # Method not allowed
        if @fallthrough
          return call_next(context)
        else
          context.response.status = HTTP::Status::METHOD_NOT_ALLOWED # 405
          context.response.headers["Allow"] = "GET, HEAD"
          return
        end
      end

      # Adjust baked key generation based on mount_path
      baked_key = if @mount_path == "/"
                    Path.posix(URI.decode(request_path)).relative_to("/").to_s
                  else
                    Path.posix(URI.decode(request_path)).relative_to(@mount_path).to_s
                  end

      # Attempt to serve the direct path
      if serve_baked_key(context, baked_key)
        return
      end

      # If direct path failed, and it's a "directory" path (ends with / or is "." for root),
      # and @serve_index_html is true, try serving an index.html file from that path.
      if @serve_index_html && (request_path.ends_with?('/') || request_path == ".")
        index_key = (baked_key == ".") ? "index.html" : Path.posix(baked_key).join("index.html").normalize.to_s
        if serve_baked_key(context, index_key)
          return
        end
      end

      # If nothing worked, fall through to the next handler.
      call_next(context)
    end

    # Helper to serve a file from BakedFileSystem using its key.
    private def serve_baked_key(context : HTTP::Server::Context, baked_key : String)
      Log.debug { "Attempting to serve baked key: '#{baked_key}' from #{@baked_fs_class}" }

      # Try compressed versions first if client supports it
      accept_encoding = context.request.headers["Accept-Encoding"]?
      if accept_encoding
        if accept_encoding.includes?("br") && serve_compressed_file(context, baked_key + ".br", "br")
          return true
        elsif accept_encoding.includes?("gzip") && serve_compressed_file(context, baked_key + ".gz", "gzip")
          return true
        end
      end

      # Check for file existence in the BakedFileSystem first.
      unless @baked_fs_class.get?(baked_key)
        Log.debug { "Baked key not found: '#{baked_key}' in #{@baked_fs_class}" }
        return false # Not served, allow fallthrough
      end

      begin
        # Now that we know it exists, get it.
        io = @baked_fs_class.get(baked_key)
        extension = Path.new(baked_key).extension.to_s # .to_s handles nil if no extension
        context.response.content_type = MIME.from_extension?(extension) || "application/octet-stream"
        @cache_control.try { |value|
          context.response.headers["Cache-Control"] = value
        }
        # For GET requests, we copy the IO content to the response.
        if context.request.method == "GET"
          IO.copy(io, context.response)
        else
          context.response.content_length = io.size
        end
        # Served
        Log.debug { "Successfully served baked key: '#{baked_key}'" }
        true
      rescue ex
        Log.error(exception: ex) { "Error serving baked key: '#{baked_key}'" }
        context.response.status = :internal_server_error
        context.response.print "Error serving file."
        true
      ensure
        io.try &.close
      end
    end

    # Helper to serve a compressed file from BakedFileSystem.
    private def serve_compressed_file(context : HTTP::Server::Context, compressed_key : String, encoding : String) : Bool
      Log.debug { "Attempting to serve compressed file: '#{compressed_key}' with encoding: #{encoding}" }

      # Check if compressed file exists
      unless @baked_fs_class.get?(compressed_key)
        Log.debug { "Compressed file not found: '#{compressed_key}'" }
        return false
      end

      begin
        io = @baked_fs_class.get(compressed_key)
        # For content type, use the original file extension (remove .gz or .br)
        original_key = compressed_key.gsub(/\.gz$|\.br$/, "")
        extension = Path.new(original_key).extension.to_s
        context.response.content_type = MIME.from_extension?(extension) || "application/octet-stream"
        context.response.headers["Content-Encoding"] = encoding
        @cache_control.try { |value|
          context.response.headers["Cache-Control"] = value
        }

        # For GET requests, we copy the IO content to the response.
        if context.request.method == "GET"
          IO.copy(io, context.response)
        else
          context.response.content_length = io.size
        end

        Log.debug { "Successfully served compressed file: '#{compressed_key}'" }
        true
      rescue ex
        Log.error(exception: ex) { "Error serving compressed file: '#{compressed_key}'" }
        context.response.status = :internal_server_error
        context.response.print "Error serving file."
        true
      ensure
        io.try &.close
      end
    end
  end
end
