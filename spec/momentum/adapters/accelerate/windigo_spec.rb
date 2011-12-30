require File.expand_path("../../../../support/helpers", __FILE__)

require "momentum"

describe Momentum::Adapters::Accelerate::Windigo do
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
    puts "sock up"
    sock
  end

  let(:server) { Momentum::Adapters::Accelerate::Windigo.new(app, listeners: socket_file) }
  
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
      while line = socket.gets and !line.strip.empty?
        puts "response: "+line
      end
    end
  end
end