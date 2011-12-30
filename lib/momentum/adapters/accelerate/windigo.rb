module Momentum::Adapters
  class Accelerate
    class Windigo < Unicorn::HttpServer
      # once a client is accepted, it is processed in its entirety here
      # in 3 easy steps: read request, call app, write app response
      def process_client(client)
        len = client.read(4).unpack('L').first
        puts "read length #{len}"
        data = client.read(len)
        puts "read the request"
        
        request = Marshal.load(data)

        status, headers, body = @app.call(request.to_rack_env)
        headers['status'] = status
        client.write(body)
        client.close # flush and uncork socket immediately, no keepalive
      end

    end
  end
end