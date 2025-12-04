require "./spec_helper"

# Test BakedFileSystem class
class TestFS
  extend BakedFileSystem
end

describe BakedFileHandler do
  describe "basic functionality" do
    it "can create handler with BakedFileSystem class" do
      handler = BakedFileHandler::BakedFileHandler.new(TestFS)
      handler.should_not be_nil
    end

    it "has correct version" do
      BakedFileHandler::VERSION.should eq("0.1.1")
    end
  end
end
