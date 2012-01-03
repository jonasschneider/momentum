module Momentum
  class Connection < EventMachine::Connection
    HTTP_RESPONSE = "HTTP/1.0 505 HTTP Version not supported\r\nConnection: close\r\n\r\n<h1>505 HTTP Version not supported</h1>This is a SPDY server."
    attr_accessor :backend

    def initialize(*args)
      super
      @zlib = SPDY::Zlib.new

      @df = SPDY::Protocol::Data::Frame.new
      @sr = SPDY::Protocol::Control::SynReply.new({:zlib_session => @zlib})
      @ss = SPDY::Protocol::Control::SynStream.new({:zlib_session => @zlib})
      @h = SPDY::Protocol::Control::Headers.new({:zlib_session => @zlib})

      @next_stream_id = 0
      @parser = ::SPDY::Parser.new
      @parser.on_headers_complete do |stream_id, associated_stream, priority, headers|
        stream = RequestStream.new(stream_id, self, headers, backend)
        stream.process_request!
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
      @could_be_http = true
    end

    def post_init
      peername = get_peername
      if peername
        @peer = Socket.unpack_sockaddr_in(peername).pop
        logger.info "Connection from: #{@peer}"
      end
    end

    def send_data(data)
      logger.debug "<< #{hex data[0..19]} (len=#{data.size}, first 20 shown)" if trace?
      super(data)
    end

    def receive_data(data)
      logger.debug ">> #{hex data}" if trace?
      if @could_be_http
        if is_http?(data)
          send_data HTTP_RESPONSE
          close_connection_after_writing
          return
        else
          @could_be_http = false
        end
      end
      @parser << data
    end

    def is_http?(data)
      methods = %w(GET POST PUT DELETE HEAD TRACE OPTIONS CONNECT)
      methods.any? do |method|
        data[0,method.length].upcase == method
      end
    end

    def send_syn_stream(associated_id, headers)
      @next_stream_id += 2
      logger.debug "< SYN_STREAM stream=#{@next_stream_id}, associated=#{associated_id}"
      @ss.create({:stream_id => @next_stream_id, :headers => headers})
      @ss.associated_to_stream_id = associated_id # strangely, #create fails there
      send_data @ss.to_binary_s
    end

    def send_syn_reply(stream, headers)
      logger.debug "< SYN_REPLY stream=#{stream}"
      send_data @sr.create({:stream_id => stream, :headers => headers}).to_binary_s
    end

    def send_headers(stream, headers)
      logger.debug "< HEADERS stream=#{stream}"
      send_data @h.create({:stream_id => stream, :headers => headers}).to_binary_s
    end

    def send_data_frame(stream, data, fin = false)
      flags = (fin ? 1 : 0)
      logger.debug "< DATA stream=#{stream}, len=#{data.size}, flags=#{flags}" if trace?
      send_data @df.create(:stream_id => stream, :data => data, :flags => flags).to_binary_s
    end

    def send_fin(stream)
      send_data_frame(stream, '', true)
    end

    def unbind
      logger.info "CONNECTION CLOSED"
    end

    def trace?
      ENV["TRACE"]
    end

    def logger
      Momentum.logger
    end

    def hex(data)
      data.unpack("C*").map{|i| i.to_s(16).rjust(2, '0')}.join(' ')
    end
  end
end