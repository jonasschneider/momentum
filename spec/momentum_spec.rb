require File.expand_path("../helpers", __FILE__)

require "momentum"
require "rack"

class DumbSPDYClient < EventMachine::Connection
  class << self
    attr_accessor :body
    attr_accessor :body_chunk_count
  end
  
  def post_init
   @parser = ::SPDY::Parser.new
   @body = ""
   @body_chunk_count = 0
   
   @parser.on_body do |id, data|
     @body << data
     @body_chunk_count += 1
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
  
  it "works as a simple Rack client" do
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, [response]] }
    
    EM.run do
      Momentum.start(app)
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end
    
    DumbSPDYClient.body.should == response
    DumbSPDYClient.body_chunk_count.should == 2 # data and separate FIN
  end
  
  it "chunks up long responses" do
    one_chunk = 4096
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ['x'*one_chunk*3]] }
    
    EM.run do
      Momentum.start(app)
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end
    
    DumbSPDYClient.body_chunk_count.should == 3
  end
  
  it "works as an HTTP proxy" do
    begin
      pid = fork do 
        Rack::Server.start(
          :app => lambda do |e|
            [200, {'Content-Type' => 'text/html'}, [response]]
          end,
          :server => 'webrick',
          :Port => 5556
        )
      end
      
      sleep 1 until is_port_open?('localhost', 5556)
      
      EM.run do
        Momentum.start_proxy('localhost', 5556)
        EventMachine::connect 'localhost', 5555, DumbSPDYClient
      end
      
      DumbSPDYClient.body.should == response
      DumbSPDYClient.body_chunk_count.should == 2
    ensure
      Process.kill("KILL", pid)
    end
  end
end