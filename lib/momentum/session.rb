require 'spdy'
require 'eventmachine'

module Momentum
  class Session < ::EventMachine::Connection
    attr_accessor :app
    
    def initialize(*args)
      super
      @zlib = SPDY::Zlib.new
      
      @stream_id = 1
      @parser = ::SPDY::Parser.new
      @parser.on_headers_complete do |stream_id, associated_stream, priority, headers|
        req = Request.new(stream_id: stream_id, associated_stream: associated_stream, priority: priority, headers: headers, zlib: @zlib)
        logger.info "got a request to #{req.uri}"
        
        @streams << req
        
        send_data req.syn_reply.to_binary_s
        send_data req.data_frame('yep, that worked').to_binary_s
        send_data req.fin_frame.to_binary_s
      end
      
      @parser.on_body             { |stream_id, data| 
      
      }
      @parser.on_message_complete { |stream_id| 
      
      }
      
      @parser.on_ping do |id|
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
      logger.debug "<< #{data.inspect}"
      super
    end
  
    def receive_data(data)
      logger.debug ">> #{data.inspect}"
      @parser << data
    end
  
    protected
    
    def logger
      Momentum.logger
    end
  end
end