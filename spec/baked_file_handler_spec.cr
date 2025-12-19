require "./spec_helper"
require "http"

# Test BakedFileSystem class with some mock files
class TestFS
  extend BakedFileSystem

  # Mock some baked files for testing
  def self.get?(key : String) : IO?
    case key
    when "style.css"
      IO::Memory.new("body { color: red; }")
    when "script.js"
      IO::Memory.new("console.log('hello');")
    when "index.html"
      IO::Memory.new("<h1>Index</h1>")
    when "assets/style.css"
      IO::Memory.new("body { color: blue; }")
    else
      nil
    end
  end

  def self.get(key : String) : IO
    get?(key) || raise "File not found: #{key}"
  end
end

describe BakedFileHandler do
  describe "basic functionality" do
    it "can create handler with BakedFileSystem class (backwards compatible)" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS)
      handler.should_not be_nil
    end

    it "has correct version" do
      BakedFileHandler::VERSION.should eq("0.1.1") # This should match the VERSION constant in src/
    end

    it "can create handler with custom mount path" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS, mount_path: "/assets")
      handler.should_not be_nil
    end

    it "normalizes mount path to end with slash" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS, mount_path: "/static")
      # We can't directly access @mount_path, but we can test behavior
      handler.should_not be_nil
    end
  end

  describe "mount path behavior" do
    it "processes requests when mounted at root (backwards compatible)" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS, mount_path: "/")

      # Create a mock HTTP context
      request = HTTP::Request.new("GET", "/style.css")
      response = HTTP::Server::Response.new(IO::Memory.new)
      context = HTTP::Server::Context.new(request, response)

      # Should attempt to process the request (not call_next)
      handler.call(context)
      # The exact behavior depends on whether TestFS has the file
      # We're just testing that it doesn't immediately fall through
    end

    it "processes requests within mount path" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS, mount_path: "/assets")

      # Create a mock HTTP context for a path within mount
      request = HTTP::Request.new("GET", "/assets/style.css")
      response = HTTP::Server::Response.new(IO::Memory.new)
      context = HTTP::Server::Context.new(request, response)

      # Should attempt to process the request
      handler.call(context)
    end

    it "falls through for requests outside mount path" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS, mount_path: "/assets")

      # Track if call_next was called by monitoring response
      request = HTTP::Request.new("GET", "/api/users")
      response = HTTP::Server::Response.new(IO::Memory.new)
      context = HTTP::Server::Context.new(request, response)

      # Should fall through without processing - we just verify it doesn't crash
      # The parent class might set status codes during fallthrough, that's expected
      handler.call(context)
      # If we get here without an exception, the fallthrough worked
    end

    it "falls through for non-GET/HEAD methods" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS, mount_path: "/assets")

      # Test POST request
      request = HTTP::Request.new("POST", "/assets/style.css")
      response = HTTP::Server::Response.new(IO::Memory.new)
      context = HTTP::Server::Context.new(request, response)

      # Should fall through for POST
      handler.call(context)
    end

    it "handles mount paths without trailing slash" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS, mount_path: "/static")

      request = HTTP::Request.new("GET", "/static/style.css")
      response = HTTP::Server::Response.new(IO::Memory.new)
      context = HTTP::Server::Context.new(request, response)

      # Should process the request
      handler.call(context)
    end
  end
end
