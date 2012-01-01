require File.expand_path("../support/helpers", __FILE__)

require "momentum"
require File.expand_path("../support/dummy_backend_response", __FILE__)
require File.expand_path("../support/dumb_spdy_client", __FILE__)
require "rack"

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
end