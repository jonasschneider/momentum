module Momentum
  REJECTED_HEADERS = ['Accept-Ranges', 'Connection', 'P3p', 'Ppserver',
    'Server', 'Transfer-Encoding', 'Vary']
  class Session < ::EventMachine::Connection
    attr_accessor :backend
    
    def initialize(*args)
      super
      @zlib = SPDY::Zlib.new
      
      @df = SPDY::Protocol::Data::Frame.new
      @sr = SPDY::Protocol::Control::SynReply.new({:zlib_session => @zlib})
      
      @stream_id = 1
      @parser = ::SPDY::Parser.new
      @parser.on_headers_complete do |stream_id, associated_stream, priority, headers|
        req = Request.new(stream_id: stream_id, associated_stream: associated_stream, priority: priority, headers: headers, zlib: @zlib)
        logger.info "got a request to #{req.uri} => #{headers.inspect}"
        
        send_buffer = ''
        
        #@streams << req
        reply = @backend.prepare(req)
        
        reply.on_headers do |headers|
          
          
          logger.debug "response headers: #{headers.inspect}"
          send_syn_reply stream_id, headers
        end
        stream = Stream.new stream_id, self
        
        reply.on_body do |chunk|
          # Spdy.logger.debug "Stream #{@stream_id} send_data (data=#{@data.size})"
          #send_buffer << chunk
          stream.write chunk
          
        end
        
        reply.on_complete do
          stream.eof!
        end
        
        reply.dispatch!
      end
      
      @parser.on_body             { |stream_id, data| 
      
      }
      @parser.on_message_complete { |stream_id| 
      
      }
      
      @parser.on_ping do |id|
        logger.debug "> Ping #{id}"
        pong = SPDY::Protocol::Control::Ping.new
        pong.ping_id = id
        send_data pong.to_binary_s
      end

      @streams = []
    end
  
    def post_init
      peername = get_peername
      if peername
        @peer = Socket.unpack_sockaddr_in(peername).pop
        logger.info "Connection from: #{@peer}"
      end
    end
    
    def send_data(data)
      #logger.debug "<< #{data.inspect}"
      super
    end
  
    def receive_data(data)
      #logger.debug ">> #{data.inspect}"
      @parser << data
    end
    
    def send_syn_reply(stream, headers)
      send_data @sr.create({:stream_id => stream, :headers => headers}).to_binary_s
    end
    
    def send_data_frame(stream, data, fin = false)
      send_data @df.create(:stream_id => stream, :data => data, :flags => (fin ? 1 : 0)).to_binary_s
    end
    
    def send_fin(stream)
      send_data @df.create(:stream_id => stream, :flags => 1, :data => '').to_binary_s
    end
    
    def logger
      Momentum.logger
    end
  end
end