require "timeout"

shared_examples "Backend server push" do
  context "server push" do
    let(:app) { lambda { |env|
      env['spdy'].push('/test.js')
      [given_response_status, given_response_headers, [given_response_body]]
    } }
    
    it "works" do
      dispatch!
      @pushes.should == ['/test.js']
    end
  end
end

shared_examples "Momentum backend" do 
  let(:rack_env) { given_request_headers }
  let(:valid_request_headers) { { 'method' => 'get', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' } }
  let(:given_request_headers) { valid_request_headers }
  
  let(:given_response_status) { 200 }
  let(:given_response_body) { 'hello from my rack app' }
  let(:given_response_headers) { {"Content-Type" => "text/plain" } }

  let(:request) { Momentum::Request.new(
    :headers => given_request_headers
  ) }
  
  let(:backend_response) { backend.prepare(request) }
  
  def dispatch!
    return if @dispatched
    backend_response.on_complete do
      EM.stop
    end
    
    @headers = {}.tap do |headers|
      backend_response.on_headers do |h|
        headers.merge!(h)
      end
    end
    
    @body = ''.tap do |data|
      backend_response.on_body do |c|
        data << c
      end
    end
    
    @pushes = [].tap do |data|
      backend_response.on_push do |c|
        data << c
      end
    end
    
    Timeout::timeout(4) {
      EM.run do
        dispatch_start_time = Time.now
        backend_response.dispatch!
        dispatch_duration = Time.now - dispatch_start_time
        dispatch_duration.should < 0.02
      end
    }
    
    @dispatched = true
    
  ensure
    EM.stop if EM.reactor_running?
  end
  
  def response_headers
    dispatch!
    @headers
  end
  
  def response_body
    dispatch!
    @body
  end
  
  context "request headers" do
    let(:given_request_headers) { valid_request_headers.merge({'a' => 'b'}) }
    
    it "passes them on" do
      dispatch!
      # This will still break the Proxy if it fails to pass the headers because only the given_headers are webmocked.
      # Since Proxy depends on Local, all is well... this still sucks.
      # FIXME
    end
  end

  context "response headers" do
    let(:given_response_headers) { {"Content-Type" => "text/plain", 'Me-Pro' => 'Yup'} }
    
    it "passes them on" do
      response_headers['me-pro'].should == 'Yup'
    end
    
    it "sets :status and :version" do
      response_headers['status'].should == '200'
      response_headers['version'].should == 'HTTP/1.1'
    end
  end

  describe "#body" do
    it "fetches the response body" do
      response_body.should == given_response_body
    end
  end
end