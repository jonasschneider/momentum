require File.expand_path("../../../helpers", __FILE__)

require "momentum"
require "rack"

describe Momentum::Backend::Proxy do
  let(:response) { "ohai from my app" }
  
  before(:all) do
    @server_pid = fork do 
      Rack::Server.start(
        :app => lambda do |e|
          [200, {'Content-Type' => 'text/html'}, [response]]
        end,
        :server => 'webrick',
        :Port => 5556
      )
    end
    sleep 1 until is_port_open?('localhost', 5556)
  end
  
  after(:all) do
    Process.kill "KILL", @server_pid
  end
  
  let(:backend) { Momentum::Backend::Proxy.new('localhost', 5556) }
  
  describe "after making a request" do
    let(:request) { stub(:headers => { :url => '/' }, :uri => URI.parse('/')) }
    let(:reply) { backend.prepare(request) }
    
    def dispatch!
      EM.run do
        reply.dispatch!
      end
    end
    
    before :each do
      reply.on_complete do
        EM.stop
      end
    end
    
    describe "#body" do
      it "fetches the response body" do
        data = ''
        reply.on_body do |c|
          data << c
        end
        dispatch!
        
        data.should == response
      end
    end
  end
end