module Momentum::Adapters
  class Accelerate
    class Windigo < Unicorn::HttpServer
      HEADERS = 0x01
      BODY_CHUNK = 0x02
      SPDY_PUSH = 0x03
      
      def process_client(client)
        len = client.read(4).unpack('L').first
        data = client.read(len)
        request = Marshal.load(data)
        
        env = request.to_rack_env
        env['spdy'] = Momentum::AppDelegate.new @req do |type, payload|
          if type == :push
            client.write(SPDY_PUSH)
            data = payload.force_encoding('ASCII-8BIT')
            client.write [data.length].pack('L')
            client.write(data)
          else
            raise "Unknown SPDY callback #{type}"
          end
        end

        status, headers, body = @app.call(request.to_rack_env)
        headers['status'] = status
        
        client.write(HEADERS)
        data = Marshal.dump(headers).force_encoding('ASCII-8BIT')
        client.write [data.length].pack('L')
        client.write(data)
        
        body.each do |chunk| 
          client.write(BODY_CHUNK)
          data = chunk.force_encoding('ASCII-8BIT')
          client.write [data.length].pack('L')
          client.write(data)
        end
        
        client.close
      rescue Exception => e
        puts e.inspect
        e.backtrace.each { |l| puts l }
        client.close
      end

    end
  end
end