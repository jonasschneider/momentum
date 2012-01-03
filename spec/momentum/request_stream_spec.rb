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

  let(:backend) { stub(:prepare => backend_response) }
  let(:session) { stub(:logger => stub(:debug => true, :info => true)) }
  let(:stream) { described_class.new(1, session, request_headers, backend) }

  it "sends back the response headers & body" do
    session.should_receive(:send_syn_reply).with(1, response_headers)
    session.should_receive(:send_data_frame).with(1, response_body, false)
    session.should_receive(:send_fin).with(1)
    stream.process_request!
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
      session.should_receive(:send_data_frame).with(3, pushed_resource_body, false)
      session.should_receive(:send_fin).with(3)

      session.should_receive(:send_syn_reply).with(1, response_headers)
      session.should_receive(:send_data_frame).with(1, response_body, false)
      session.should_receive(:send_fin).with(1)

      stream.process_request!
    end
  end

  let(:response_test) { 'asdf' }


  it "chunks up long responses" do
    pending
    one_chunk = 4096
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ['x'*one_chunk*3]] }

    EM.run do
      Momentum.start(Momentum::Backend.new(app))
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end

    DumbSPDYClient.body_chunk_count.should == 3
  end

  it "passes request & response headers" do
    pending
    backend = Object.new
    backend.stub(:prepare) do |req|
      req.headers['accept-encoding'].should == 'gzip,deflate,sdch'
      DummyBackendResponse.new(:headers => {'a' => 'b'})
    end

    EM.run do
      Momentum.start(backend)
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end

    DumbSPDYClient.headers['a'].should == 'b'
  end
end