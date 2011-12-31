module Momentum
  module Adapters
    class Accelerate
      class Body
        include EventMachine::Deferrable
        
        def call(body)
          body.each do |chunk|
            @body_callback.call(chunk)
          end
        end
      
        def each &blk
          @body_callback = blk
        end
      end
      
      def initialize(socket_name)
        @socket_name = socket_name
      end

      def call(env)
        req = env['spdy'].momentum_request
        puts "forwarding #{req.inspect}"
        EventMachine.connect @socket_name do |conn|
          def conn.receive_data(data)
            @on_data.call(data) if @on_data
          end
          
          def conn.on_data(&blk)
            @on_data = blk
          end
          
          def conn.unbind
            @on_close.call if @on_close
          end
          
          def conn.on_close(&blk)
            @on_close = blk
          end
          deferred_body = Body.new
          buf = ''
          conn.on_data do |data|
            buf << data
            next if buf.length < 5
            type = buf[0].to_i
            len = buf[1,4].unpack('L').first
            
            next if buf.length < (5 + len)
            body = buf[5,len]
            buf.slice!(0,(5+len))
            case type
            when Windigo::HEADERS
              headers = Marshal.load(body)
              env['async.callback'].call [headers['status'], headers, deferred_body]
            when Windigo::BODY_CHUNK
              puts "==> received #{body.length} bytes of body from backend"
              deferred_body.call [body]
            else
              raise "Wat?"
            end
          end
          
          conn.on_close do 
            EM.next_tick do
              deferred_body.succeed
            end
          end
          
          data = Marshal.dump(req).force_encoding('ASCII-8BIT')
          len = [data.length].pack('L')
          conn.send_data len
          conn.send_data data
          puts "data away"
        end
        throw :async
      end
    end
  end
end