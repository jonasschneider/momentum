require File.expand_path("../../../../support/helpers", __FILE__)

require "momentum"
include Momentum::Adapters

describe Accelerate::Windigo do
  let(:socket_file) { '/tmp/unicorn.sock' }
  let(:socket) do
    sock = nil
    Timeout.timeout(4) do
      begin
        sock = UNIXSocket.new(socket_file)
      rescue Errno::ECONNREFUSED
        sleep 0.2
        retry
      end
    end
    sock
  end

  let(:server) { Accelerate::Windigo.new(app, listeners: socket_file) }
  
  before do
    @pid = fork do
      server.start
    end
  end
  
  after do
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
end
