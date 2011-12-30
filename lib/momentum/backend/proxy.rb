module Momentum
  module Backend
    class Proxy < Base
      class Reply < Base::Reply
        def initialize(host, port, req)
          @host, @port, @req = host, port, req
        end

        def dispatch!
          url = @req.uri.dup
          url.host = @host
          url.port = @port

          http = EventMachine::HttpRequest.new(url).get :head => @req.headers
          
          http.headers do |headers|
            headers['status'] = headers.http_status
            headers['version'] = headers.http_version
            
            @on_headers.call cleanup_headers(headers) if @on_headers
          end
          
          http.stream do |chunk|
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