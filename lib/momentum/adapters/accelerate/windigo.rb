module Momentum::Adapters
  class Accelerate
    class Windigo < Unicorn::HttpServer
      SPDY_DATA = 0x02
      BODY_CHUNK = 0x01

      def process_client(client)
        len = client.read(4).unpack('L').first
        data = client.read(len)
        
        request = Marshal.load(data)

        status, headers, body = @app.call(request.to_rack_env)
        headers['status'] = status

        body.each do |chunk| 
          client.write(BODY_CHUNK)
          data = chunk.force_encoding('ASCII-8BIT')
          client.write [data.length].pack('L')
          client.write(data)
        end

        client.close
      rescue e
        puts e.inspect
        client.close
      end

    end
  end
end