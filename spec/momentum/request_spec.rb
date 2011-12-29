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
    
    it "adds the URL to the env" do
      req = Momentum::Request.new headers: { "a" => "b", "url" => '/favicon.ico', "method" => 'get' }
      req.to_rack_env['PATH_INFO'].should == '/favicon.ico'
      req.to_rack_env['SCRIPT_NAME'].should be_nil
    end
  end
end