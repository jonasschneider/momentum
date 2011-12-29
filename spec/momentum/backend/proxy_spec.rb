require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"
require "rack"

describe Momentum::Backend::Proxy do
  after(:each) do
    Process.kill "KILL", @server_pid if @server_pid
  end

  let(:backend) do
    @server_pid = fork do 
      Rack::Server.start(
        :app => app,
        :server => 'webrick',
        :Port => 5556
      )
    end
    sleep 0.1 until is_port_open?('localhost', 5556)
    
    Momentum::Backend::Proxy.new('localhost', 5556)
  end

  include_examples "Momentum backend"
end