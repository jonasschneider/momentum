require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"
require "rack"
require 'webmock/rspec'

describe Momentum::Adapters::Proxy do
  let(:app) { lambda { |env| sleep 1; [given_response_status, given_response_headers, [given_response_body]] } }
  let(:backend) do
    a = Momentum::Adapters::Defer.new(app)
    Momentum::Backend.new(a)
  end
  
  include_examples "Momentum backend"
end