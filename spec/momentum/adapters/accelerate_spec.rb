require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"
require "rack"

describe Momentum::Adapters::Accelerate do
  let(:app) { lambda { |env| [given_response_status, given_response_headers, [given_response_body]] } }

  let(:server) { puts "server listening on #{@socket_name}"
    Momentum::Adapters::Accelerate::Windigo.new(app, listeners: @socket_name) }

  before :each do
    t = Tempfile.new('momentum-spec')
    @socket_name = t.path
    t.unlink
    
    @pid = fork do
      server.start
    end
    sleep 0.1
  end
  
  after :each do
    Process.kill(:TERM, @pid)
  end

  let(:backend) do
    puts "backend looking at #{@socket_name}"
    app = Momentum::Adapters::Accelerate.new(@socket_name)
    Momentum::Backend.new(app)
  end

  include_examples "Momentum backend"
end