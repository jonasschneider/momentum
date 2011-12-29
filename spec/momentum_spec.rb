require File.expand_path("../helpers", __FILE__)

require "momentum"
require "rack"

class DumbSPDYClient < EventMachine::Connection
  class << self
    attr_accessor :body
  end
  
  def post_init
   @parser = ::SPDY::Parser.new
   @body = ""
   
   @parser.on_body do |id, data|
     @body << data
   end
     
   @parser.on_message_complete do
     DumbSPDYClient.body = @body
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
        Momentum.start_proxy('localhost', 5557)
        EventMachine::connect 'localhost', 5555, DumbSPDYClient
      end
      
      DumbSPDYClient.body.should == response
      
    ensure
      Process.kill("KILL", pid)
    end
  end
end