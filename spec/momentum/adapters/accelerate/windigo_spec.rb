require File.expand_path("../../../../support/helpers", __FILE__)

require "momentum"
include Momentum::Adapters

describe Accelerate::Windigo do
  let(:socket) do
    sock = nil
    sleep 0.2
    Timeout.timeout(4) do
      begin
        sock = UNIXSocket.new(@socket_name)
      rescue Errno::ECONNREFUSED
        sleep 0.2
        retry
      end
    end
    sock
  end

  let(:server) { Accelerate::Windigo.new(app, listeners: @socket_name) }
  
  before :each do
    t = Tempfile.new('momentum-spec')
    @socket_name = t.path
    t.unlink
    
    @pid = fork do
      server.start
    end
  end
  
  after :each do
    Process.kill(:TERM, @pid)
  end
  
  let(:headers) { { 'method' => 'get', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' } }
  
  let(:request) { Momentum::Request.new(headers: headers) }
  
  def send_request!
    data = Marshal.dump(request).force_encoding('ASCII-8BIT')
    len = [data.length].pack('L')
    socket.write len
    socket.write data
  end
  
  def read_frame
    type = socket.read(1).to_i

    len = socket.read(4).unpack('L').first
    body = socket.read(len)
    { type: type, body: body }
  end
  
  context "response headers" do
    let(:response_headers) { {"Content-Type" => "text/plain"} }
    let(:app) { lambda { |env| [200, response_headers, ['ohai']] } }
    
    it "sends them back" do
      send_request!
      f = read_frame
      f[:type].should == Accelerate::Windigo::HEADERS
      Marshal.load(f[:body]).should == response_headers.merge("status" => 200)
    end
  end
  
  context "response body" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, ['ohai']] } }
    
    it "gets returned" do
      send_request!
      headers = read_frame
      f = read_frame
      f[:type].should == Accelerate::Windigo::BODY_CHUNK
      f[:body].should  == 'ohai'
    end
  end

  context "chunked response body" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, ['ohai', 'test']] } }

    it "gets returned" do
      send_request!
      headers = read_frame
      f = read_frame
      f[:type].should == Accelerate::Windigo::BODY_CHUNK
      f[:body].should == 'ohai'
      
      f = read_frame
      f[:type].should == Accelerate::Windigo::BODY_CHUNK
      f[:body].should == 'test'
    end
  end
  
  context "SPDY Server Push" do
    class PushingApp
      def self.call(env)
        if env['spdy']
          env['spdy'].push('/application.js')
        end
        [200, {"Content-Type" => "text/plain"}, ['ohai', 'test']]
      end
    end
    let(:app) { PushingApp }

    it "returns the body" do
      send_request!
      push = read_frame
      headers = read_frame
      
      f = read_frame
      f[:type].should == Accelerate::Windigo::BODY_CHUNK
      f[:body].should == 'ohai'
      
      f = read_frame
      f[:type].should == Accelerate::Windigo::BODY_CHUNK
      f[:body].should == 'test'
    end
    
    it "prepends a SPDY push frame" do
      send_request!
      
      f = read_frame
      f[:type].should == Accelerate::Windigo::SPDY_PUSH
      f[:body].should == '/application.js'
    end
  end
end
