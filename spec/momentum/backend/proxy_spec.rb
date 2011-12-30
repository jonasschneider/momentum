require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"
require "rack"
require 'webmock/rspec'

describe Momentum::Backend::Proxy do
  let(:backend) do
    stub_request(:get, "http://localhost:5556/").
      with(:headers => given_request_headers).
      to_return(:status => given_response_status, :body => given_response_body, :headers => given_response_headers)

    app = Momentum::Backend::Proxy.new('localhost', 5556)
    Momentum::Backend::Local.new(app)
  end
  
  include_examples "Momentum backend"
end