require File.expand_path("../../support/helpers", __FILE__)

require "momentum"
require File.expand_path("../../support/dummy_backend_response", __FILE__)

# TODO: Avoid push recursion
# TODO: Proper error handling
describe Momentum::RequestStream do
  let(:response_headers) { { 'a' => 'b' } }
  let(:response_body) { 'test' }
  let(:backend_response) { DummyBackendResponse.new(:headers => response_headers, :body => response_body) }
  let(:request_headers) { { 'method' => 'get', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' } }

  let(:backend) { double(:prepare => backend_response) }
  let(:session) { double('Session').as_null_object }
  let(:stream) do
    described_class.new(1, session, backend).tap do |stream|
      stream.add_headers(request_headers)
    end
  end

  before :each do
    session.stub(:send_data_frame) # We check for Stream#send_data
  end

  it "sends back the response headers & body" do
    session.should_receive(:send_syn_reply).with(1, response_headers)
    stream.should_receive(:send_data).with(response_body)
    session.should_receive(:send_fin).with(1)
    stream.process_request!
  end

  context "spdy_info[:remote_addr]" do
    let(:address) { '127.0.0.1' }

    it "gets set to the connection's remote IP" do
      session.stub(:peer) { address }

      backend.should_receive(:prepare) do |req|
        req.spdy_info[:remote_addr].should == address
      end

      stream.process_request!
    end
  end

  context "Request body" do
    it "passes request body" do
      backend.stub(:prepare) do |req|
        req.spdy_info[:body].should == 'ohai'
        DummyBackendResponse.new(:headers => response_headers)
      end
      stream.add_body('ohai')
      stream.process_request!
    end
  end

  context "Request headers" do
    it "passes request headers" do
      backend = Object.new
      backend.stub(:prepare) do |req|
        req.headers.should == request_headers

        DummyBackendResponse.new(:headers => response_headers)
      end

      stream.process_request!
    end
  end

  context "Server Push" do
    let(:pushed_resource_headers) { { 'second' => 'value' } }
    let(:pushed_resource_body) { 'my asset' }

    before :each do
      backend.stub(:prepare) do |req|
        if req.spdy_info[:headers]['url'] == '/'
          DummyBackendResponse.new :headers => response_headers, :body => response_body, :pushes => ['/test.js']
        else
          req.spdy_info[:headers]['url'].should == '/test.js'
          req.spdy_info[:headers]['host'].should == 'localhost'
          req.spdy_info[:headers]['scheme'].should == 'http'
          req.spdy_info[:headers]['method'].should == 'get'

          DummyBackendResponse.new :headers => pushed_resource_headers, :body => pushed_resource_body
        end
      end
    end

    it "initiates a Server Push when the push callback is called" do
      # Draft 3:
      # session.should_receive(:send_syn_stream).with(1, {"host"=>"localhost", "scheme"=>"http", "path"=>"/test.js"}) { 3 }
      session.should_receive(:send_syn_stream).with(1, {"url"=>"http://localhost/test.js"}) { 3 }
      session.should_receive(:send_headers).with(3, pushed_resource_headers)
      session.should_receive(:send_data_frame).with(3, pushed_resource_body, false) # FIXME: cannot stub on the pushed stream here
      session.should_receive(:send_fin).with(3)

      session.should_receive(:send_syn_reply).with(1, response_headers)
      stream.should_receive(:send_data).with(response_body)
      session.should_receive(:send_fin).with(1)

      stream.process_request!
    end
  end
end