require File.expand_path("../../support/helpers", __FILE__)

require "momentum"
require "em-synchrony"
require "awesome_print"

require File.expand_path("../../support/blocking_spdy_client", __FILE__)
require File.expand_path("../../support/dumb_spdy_client", __FILE__)
require File.expand_path("../../support/dummy_backend_response", __FILE__)


class EventMachine::Connection
  alias_method :send_data_without_record, :send_data
  attr_accessor :__sent_data

  def send_data(data)
    @__sent_data ||= ''
    @__sent_data << data
    send_data_without_record(data)
  end
end

describe Momentum::Connection do
  let(:backend) { stub }
  let(:connection) { Momentum::Connection.new(1).tap{|c|c.backend = backend} }

  def connect
    @received_frames = []
    @parser = SPDY::Parser.new
    EM.run {
      yield
      EM.stop
    }
  end

  def send(data)
    connection.receive_data(data.force_encoding('ascii-8bit'))
  end

  def received_data
    connection.__sent_data
  end

  def should_receive(data)
    received_data.inspect.should == data.inspect
    connection.__sent_data = ''
  end

  def received_frames
    unless received_data.empty?
      parsed = (@parser << received_data)
      @received_frames += parsed
      connection.__sent_data = ''
    end
    @received_frames
  end

  def should_receive_frame(data)
    received_data.inspect.should == data.inspect
    connection.__sent_data = ''
  end

  it "sends a notice to HTTP clients" do
    connect do
      send "GET / HTTP/1.1\nHost: localhost\n\n"
      should_receive Momentum::Connection::HTTP_RESPONSE
    end
  end

  let(:response) { DummyBackendResponse.new(:headers => { 'a' => 'b' }, :body => 'test') }

  it "sends back the response headers & body" do
    connect do
      backend.stub(:prepare => response)
      send GET_REQUEST

      received_frames.length.should == 3

      headers = received_frames.shift
      headers.class.should == SPDY::Protocol::Control::SynReply
      headers.header.flags.should == 0
      headers.uncompressed_data.to_h.should == { 'a' => 'b' }

      body = received_frames.shift
      body.class.should == SPDY::Protocol::Data::Frame
      body.flags.should == 0
      body.data.should == 'test'

      fin = received_frames.shift
      fin.class.should == SPDY::Protocol::Data::Frame
      fin.flags.should == 1
      fin.len.should == 0
    end
  end

  # TODO: Avoid push recursion
  it "initiates a Server Push when the push callback is called" do
    connect do
      backend.stub(:prepare) do |req|
        if req.spdy_info[:headers]['url'] == '/'
          DummyBackendResponse.new :headers => { 'a' => 'b' }, :body => 'test', :pushes => ['/test.js']
        else
          DummyBackendResponse.new :headers => { 'second' => 'value' }, :body => 'my asset'
        end
      end
      send GET_REQUEST

      push = received_frames.shift
      push.class.should == SPDY::Protocol::Control::SynStream
      push.associated_to_stream_id.should == 1
      push.header.flags.should == 0
      push.uncompressed_data.to_h.should == { 'host' => 'titan', 'scheme' => 'http', 'path' => '/test.js' }

      headers = received_frames.shift
      headers.class.should == SPDY::Protocol::Control::Headers
      headers.header.flags.should == 0
      headers.uncompressed_data.to_h.should == { 'second' => 'value' }

      body = received_frames.shift
      body.class.should == SPDY::Protocol::Data::Frame
      body.flags.should == 0
      body.data.should == 'my asset'

      fin = received_frames.shift
      fin.class.should == SPDY::Protocol::Data::Frame
      fin.flags.should == 1
      fin.len.should == 0

      received_frames.length.should == 3 # original SYN_REPLY, DATA, FIN
    end
  end

  let(:response_test) { 'asdf' }

  it "works as a SPDY Rack server" do
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, [response_test]] }

    EM.run do
      Momentum.start(Momentum::Backend.new(app))
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end

    DumbSPDYClient.body.should == response_test
    DumbSPDYClient.body_chunk_count.should == 2 # data and separate FIN
  end

  it "chunks up long responses" do
    one_chunk = 4096
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ['x'*one_chunk*3]] }

    EM.run do
      Momentum.start(Momentum::Backend.new(app))
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end

    DumbSPDYClient.body_chunk_count.should == 3
  end

  it "passes request & response headers" do
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