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