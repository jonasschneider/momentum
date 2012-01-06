require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"
require "rack"
require 'webmock/rspec'

describe Momentum::Adapters::Proxy do
  context 'As a backend' do
    let(:backend) do
      stub_request(:get, "http://localhost:5556/").
        with(:headers => given_request_headers).
        to_return(:status => given_response_status, :body => given_response_body, :headers => given_response_headers)

      app = Momentum::Adapters::Proxy.new('localhost', 5556)
      Momentum::Backend.new(app)
    end

    include_examples "Momentum backend"
  end

  let(:backend) do
    app = Momentum::Adapters::Proxy.new('localhost', 5556)
    Momentum::Backend.new(app)
  end

  # see http://unicorn.bogomips.org/examples/nginx.conf
  context 'X-Forwarded-For header' do
    let(:client_address) { '123.231.132.0' }
    let(:request_headers) { { 'method' => 'post', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' } }
    let(:expected_upstream_headers) { request_headers.merge({ 'X-Forwarded-For' => client_address}) }

    it "gets set the to request.spdy_info[:remote_addr]" do
      stub_request(:post, "http://localhost:5556/").
        with(:headers => expected_upstream_headers).
        to_return(:status => 200, :body => 'done', :headers => {})

      request = Momentum::Request.new(:headers => request_headers)
      request.spdy_info[:remote_addr] = client_address

      response = backend.prepare(request)
      response.on_body do |data|
        data.should == 'done'
      end

      EM.run do
        response.dispatch!
        EM.stop
      end
    end
  end

  it "passes the request body on" do
    stub_request(:post, "http://localhost:5556/").
      with(:body => 'ohai').
      to_return(:status => 200, :body => 'yep', :headers => {})

    request = Momentum::Request.new(:headers => { 'method' => 'post', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' })
    request.spdy_info[:body] = 'ohai'

    response = backend.prepare(request)
    response.on_body do |data|
      data.should == 'yep'
    end

    EM.run do
      response.dispatch!
      EM.stop
    end
  end
end