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
    { type: type, len: len, body: body }
  end
  
  context "response body" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, ['ohai']] } }
    
    it "gets returned" do
      send_request!
      type = socket.read(1).to_i
      type.should == Accelerate::Windigo::BODY_CHUNK

      len = socket.read(4).unpack('L').first
      body_data = socket.read(len)
      body_data.should == 'ohai'
    end
  end

  context "chunked response body" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, ['ohai', 'test']] } }

    it "gets returned" do
      send_request!
      f = read_frame
      f[:type].should == Accelerate::Windigo::BODY_CHUNK
      f[:body].should == 'ohai'
      
      f = read_frame
      f[:type].should == Accelerate::Windigo::BODY_CHUNK
      f[:body].should == 'test'
    end
  end
end
