module Momentum
  module Backend
    class Local < Base
      class Reply < Base::Reply
        def initialize(app, req)
          @app = app
          @req = req
        end

        def dispatch!
          status, headers, body = @app.call(@req.to_rack_env)
          headers['status'] = status.to_s
          headers['version'] = 'HTTP/1.1'
          @on_headers.call cleanup_headers(headers) if @on_headers
          
          body.each do |chunk|
            @on_body.call(chunk) if @on_body
          end
          
          @on_complete.call if @on_complete
        end
      end
      
      def initialize(app)
        @app = app
      end
      
      def prepare(req)
        Reply.new(@app, req)
      end
    end
  end
end