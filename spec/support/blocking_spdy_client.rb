class BlockingSPDYClient
  include SPDY::Protocol

  def initialize(host, port)
    @sock = EventMachine::Synchrony::TCPSocket.new host, port
    @zlib = SPDY::Zlib.new
  end
  
  def request(url)
    sr = SPDY::Protocol::Control::SynStream.new({:zlib_session => @zlib})
    
    headers = {
      "accept"=>"text/html", "host"=>"127.0.0.1:9000",
      "method"=>"GET", "scheme"=>"http",
      "url"=>url,"version"=>"HTTP/1.1"
    }
    
    send_packet sr.create({:stream_id => 1, :headers => headers})
  end

  def send_packet(pckt)
    @sock.write pckt.to_binary_s
  end

  def read_packet
    buf = read(1)
    type = buf[0,1].unpack('C').first >> 7 & 0x01
    case type
      when CONTROL_BIT then
        buf << read(11)
        pckt = Control::Header.new.read(buf)
        buf << read(pckt.len-4) # FIXME: wtf?
        case pckt.type.to_i
          when 1 then # SYN_STREAM
            pckt = Control::SynStream.new({:zlib_session => @zlib})
            pckt.parse(buf)

          when 2 then # SYN_REPLY
            pckt = Control::SynReply.new({:zlib_session => @zlib})
            pckt.parse(buf)
            
          when 6 then # PING
            pckt = Control::Ping.new
            pckt.read(buf)
        end
      when DATA_BIT then
        buf << read(7)
        data = buf[5,3].unpack('nc')
        len = (data[0] << 8) + data[1]
        buf << read(len) if len > 0
        
        pckt = Data::Frame.new.read(buf)
        pckt.read(buf)
      else
        raise 'wat'
    end
    pckt
  end
  
  def read(len)
    x = @sock.read(len)
    #puts x.inspect
    x
  end
  
  def receive_data data
    @parser << data
  end
end