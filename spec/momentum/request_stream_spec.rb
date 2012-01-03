require File.expand_path("../../support/helpers", __FILE__)

require "momentum"
require File.expand_path("../../support/dummy_backend_response", __FILE__)

# TODO: Avoid push recursion
# TODO: Proper error handling
# TODO: change #send_data_frame to #write so the Stream is concerned with chunking
describe Momentum::RequestStream do
  let(:response_headers) { { 'a' => 'b' } }
  let(:response_body) { 'test' }
  let(:backend_response) { DummyBackendResponse.new(:headers => response_headers, :body => response_body) }
  let(:request_headers) { { 'method' => 'get', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' } }

  let(:backend) { double(:prepare => backend_response) }
  let(:session) { double('Session', :logger => double(:debug => true, :info => true)) }
  let(:stream) { described_class.new(1, session, request_headers, backend) }

  before :each do
    session.stub(:send_data_frame)
  end

  it "sends back the response headers & body" do
    session.should_receive(:send_syn_reply).with(1, response_headers)
    stream.should_receive(:send_data).with(response_body)
    session.should_receive(:send_fin).with(1)
    stream.process_request!
  end


  context "Request headers" do
    let(:session) { double('Session').as_null_object }

    it "passes request headers" do
      backend = Object.new
      backend.stub(:prepare) do |req|
        req.headers.should == request_headers

        DummyBackendResponse.new(:headers => response_headers)
      end

      session.should_receive(:send_syn_reply).with(1, response_headers)
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
          DummyBackendResponse.new :headers => pushed_resource_headers, :body => pushed_resource_body
        end
      end
    end

    it "initiates a Server Push when the push callback is called" do
      session.should_receive(:send_syn_stream).with(1, {"host"=>"localhost", "scheme"=>"http", "path"=>"/test.js"}) { 3 }
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