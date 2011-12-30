require "timeout"

shared_examples "Momentum backend" do 
  let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, [response]] } }
  let(:response) { 'hello from my rack app' }
  
  let(:rack_env) { { "a" => "b" } }
  
  let(:headers) { { 'method' => 'get', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' } }

  let(:request) { stub(
    :headers => headers,
    :uri => URI.parse('http://localhost/'),
    :to_rack_env => rack_env
  ) }
  
  let(:reply) { backend.prepare(request) }
  
  def dispatch!
    reply.on_complete do
      EM.stop
    end
    
    Timeout::timeout(4) {
      EM.run do
        reply.dispatch!
      end
    }
    
  ensure
    EM.stop if EM.reactor_running?
  end
  
  def response_headers
    {}.tap do |headers|
      reply.on_headers do |h|
        headers.merge!(h)
      end
      
      dispatch!
    end
  end
  
  def response_body
    ''.tap do |data|
      reply.on_body do |c|
        data << c
      end
      
      dispatch!
    end
  end
  
  context "request headers" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, [env['HTTP_ME_PRO'].inspect]] } }
    let(:headers) { { :url => '/', 'Me-pro' => 'Yup' } }
    let(:rack_env) { { "HTTP_ME_PRO" => 'Yup' } }
    
    it "passes them on" do
      response_body.should == '"Yup"'
    end
  end

  context "response headers" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain", 'Me-Pro' => 'Yup'}, ['wayne']] } }
    
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
      response_body.should == response
    end
  end
end