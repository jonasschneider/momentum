require File.expand_path("../../support/helpers", __FILE__)

require "momentum"

describe Momentum::Request do
  describe "#to_rack_env" do
    let(:headers) { { "a" => "b", "url" => '/favicon.ico', "method" => 'get', 'host' => 'titan:5555', "scheme" => "http" } }
    it "adds method to the env" do
      req = Momentum::Request.new headers: headers
      req.to_rack_env['REQUEST_METHOD'].should == 'get'
    end

    it "adds headers to the env" do
      req = Momentum::Request.new headers: headers
      req.to_rack_env['HTTP_A'].should == 'b'
    end
    
    it "adds PATH_INFO to the env" do
      req = Momentum::Request.new headers: headers
      req.to_rack_env['PATH_INFO'].should == '/favicon.ico'
    end
    
    it "adds SCRIPT_NAME to the env" do
      req = Momentum::Request.new headers: headers
      req.to_rack_env['SCRIPT_NAME'].should == ''
    end
    
    it "adds the right host to the env" do
      req = Momentum::Request.new headers: headers
      req.to_rack_env['SERVER_NAME'].should == 'titan'
      req.to_rack_env['SERVER_PORT'].should == '5555'
    end
  end
end