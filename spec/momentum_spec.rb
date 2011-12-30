require File.expand_path("../support/helpers", __FILE__)

require "momentum"
require "rack"

class DumbSPDYClient < EventMachine::Connection
  class << self
    attr_accessor :body, :body_chunk_count, :headers
  end
  
  def post_init
   @parser = ::SPDY::Parser.new
   @body = ""
   @body_chunk_count = 0
   
   @parser.on_body do |id, data|
     @body << data
     @body_chunk_count += 1
   end
   
   @parser.on_headers_complete do |a, s, d, headers|
     DumbSPDYClient.headers = headers
   end
     
   @parser.on_message_complete do
     DumbSPDYClient.body = @body
     DumbSPDYClient.body_chunk_count = @body_chunk_count
     EventMachine::stop_event_loop
   end
   
   send_data GET_REQUEST
   
  rescue Exception => e
    puts e.inspect
  end
  
  def receive_data data
    @parser << data
  end
end


describe Momentum do
  let(:response) { "ohai from my app" }

  it "also accepts a Rack app instead of a backend" do
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, [response]] }
    
    EM.run do
      Momentum.start(app)
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end
    
    DumbSPDYClient.body.should == response
    DumbSPDYClient.body_chunk_count.should == 2 # data and separate FIN
  end
  
  it "throws when something else is passed" do
    lambda {
      Momentum.start("test")
    }.should raise_error
  end
  
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
  
  class DummyReply < Momentum::Backend::Reply
    def initialize(options)
      @options = options
    end
    
    def dispatch!
      @on_headers.call(@options[:headers] || {})
      @on_complete.call
    end
  end
  
  it "passes request & response headers" do
    backend = Object.new
    backend.stub(:prepare) do |req|
      req.headers['accept-encoding'].should == 'gzip,deflate,sdch'
      DummyReply.new(:headers => {'a' => 'b'})
    end
    
    EM.run do
      Momentum.start(backend)
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end
    
    DumbSPDYClient.headers['a'].should == 'b'
  end
end