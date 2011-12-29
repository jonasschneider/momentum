module Momentum
  module Backend
    class Proxy < Base
      class Reply < Base::Reply
        def initialize(host, port, req)
          @host, @port, @req = host, port, req
        end

        def dispatch!
          url = "http://#{@host}:#{@port}#{@req.uri}"

          http = EventMachine::HttpRequest.new(url).get :head => @req.headers
          
          
          http.headers do |headers|
            headers['status'] = headers.http_status
            headers['version'] = headers.http_status
            
            @on_headers.call(headers) if @on_headers
          end
          sent_bytes = 0
          
          http.stream do |chunk|
            sent_bytes += chunk.size
            puts "#{sent_bytes} bytes sent from http"
            @on_body.call(chunk) if @on_body
          end
          
          http.callback do
            @on_complete.call if @on_complete
          end
        end
      end
      
      def initialize(host, port)
        @host, @port = host, port
      end
      
      def prepare(req)
        Reply.new(@host, @port, req)
      end
    end
  end
end