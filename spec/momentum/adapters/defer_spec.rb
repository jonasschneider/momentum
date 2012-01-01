require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"
require "rack"
require 'webmock/rspec'

describe Momentum::Adapters::Defer do
  let(:app) { lambda { |env| [given_response_status, given_response_headers, [given_response_body]] } }
  let(:backend) do
    a = Momentum::Adapters::Defer.new(app)
    Momentum::Backend.new(a)
  end
  
  include_examples "Momentum backend"
  include_examples "Backend server push"
  
  context "push callback" do
    let(:backend) do
      a = Momentum::Adapters::Defer.new(app)
      Momentum::Backend.new(a)
    end

    let(:app) { lambda { |env|
      puts "pushing to #{env['spdy'].inspect}"
      env['spdy'].push('/test.js')
      [200, {}, []]
    } }

    it "gets called in the main thread" do
      delegate = stub
      ran_in_thread = nil
      delegate.stub(:push) do |url| 
        ran_in_thread = Thread.current
      end
      backend_response.stub(:build_delegate => delegate)
      dispatch!
      
      ran_in_thread.should == Thread.current
    end
  end
end