require 'spdy'
require 'eventmachine'

module Momentum
  class Session < ::EventMachine::Connection
    attr_accessor :app
    def initialize(*args)
      super
      @stream_id = 1
      @parser = ::SPDY::Parser.new
      @parser.on_headers_complete do |stream_id, associated_stream, priority, headers|
        puts "got a request #{headers.inspect}"
      end
      
      @parser.on_body             { |stream_id, data| 
      
      }
      @parser.on_message_complete { |stream_id| 
      
      }
      
      @parser.on_ping do |id|
        pong = SPDY::Protocol::Control::Ping.new
        pong.ping_id = id
        send_data pong.to_binary_s
        logger.debug "PONG #{id}"
      end

      @streams = {}
    end
  
    def post_init
      
      peername = get_peername
      if peername
        @peer = Socket.unpack_sockaddr_in(peername).pop
        logger.info "Connection from: #{@peer}"
      end
    end
  
    def receive_data(data)
      logger.debug "receive_data #{data.size} bytes"
      if data.size < 20
        logger.debug data.inspect
      end
      @parser << data
    end
  
    protected
    
    def logger
      Momentum.logger
    end
  end
end