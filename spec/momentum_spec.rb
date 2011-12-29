require File.expand_path("../helpers", __FILE__)

require "momentum"

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
  def app
    lambda { |env| [200, {"Content-Type" => "text/plain"}, ["ohai from the rack app"]] }
  end
  
  it "works" do
    EM.run do
      Momentum.start(app)
      EventMachine::connect 'localhost', 5555, DumbSPDYClient
    end
    
    DumbSPDYClient.body.should == 'ohai from the rack app'
  end
end