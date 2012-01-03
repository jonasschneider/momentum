require File.expand_path("../../support/helpers", __FILE__)

require "momentum"

describe Momentum::Request do
  let(:valid_headers) { { 'method' => 'get', 'version' => 'HTTP/1.1', 'url' => '/test.css', 'host' => 'titan:5555', 'scheme' => 'http' } }
  %w(method url version).each do |header|
    it "raises when :#{header} is missing" do
      valid_headers.delete header
      lambda {
        Momentum::Request.new headers: valid_headers
      }.should raise_error
    end
  end

  describe "#to_rack_env" do
    let(:headers) { valid_headers.merge({ "a" => "b"}) }

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
      req.to_rack_env['PATH_INFO'].should == '/test.css'
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