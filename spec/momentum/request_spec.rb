require File.expand_path("../../support/helpers", __FILE__)

require "momentum"

describe Momentum::Request do
  describe "#to_rack_env" do
    it "adds method to the env" do
      req = Momentum::Request.new headers: { "url" => '/', "method" => 'get' }
      req.to_rack_env['REQUEST_METHOD'].should == 'get'
    end

    it "adds headers to the env" do
      req = Momentum::Request.new headers: { "a" => "b", "url" => '/', "method" => 'get' }
      req.to_rack_env['HTTP_A'].should == 'b'
    end
  end
end