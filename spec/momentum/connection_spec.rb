require File.expand_path("../../support/helpers", __FILE__)

require "momentum"
require "em-synchrony"

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
    EM.run {
      yield
      EM.stop
    }
  end
  
  def send(data)
    connection.receive_data(data)
  end
  
  def should_receive(data)
    connection.__sent_data.should == data
    connection.__sent_data = ''
  end
  
  it "sends a notice to HTTP clients" do
    connect do
      puts "connected"
      send("GET / HTTP/1.1\nHost: localhost\n\n")
      should_receive Momentum::Connection::HTTP_RESPONSE
    end
  end
  
  let(:response) { 'asdf' }
  
  it "works as a SPDY Rack server" do
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, [response]] }
    
    EM.run do
      Momentum.start(Momentum::Backend.new(app))
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end
    
    DumbSPDYClient.body.should == response
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