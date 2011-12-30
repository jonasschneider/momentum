module Momentum
  module Backend
    class Local < Base
      class Reply < Base::Reply
        AsyncResponse = [-1, {}, []].freeze
        
        def initialize(app, req)
          @app = app
          @req = req
        end

        def dispatch!
          env = @req.to_rack_env
          env['async.callback'] = lambda {|response|
            process_response(response)
          }
          env['momentum.request'] = @req
          
          response = AsyncResponse
          catch(:async)  do
            response = @app.call(env)
          end
          process_response(response)
        end

        protected
        def process_response(response)
          return if response.first == AsyncResponse.first
          
          status, headers, body = response
          headers['status'] = status.to_s
          headers['version'] = 'HTTP/1.1'
          @on_headers.call cleanup_headers(headers) if @on_headers
          
          body.each do |chunk|
            @on_body.call(chunk) if @on_body
          end
          
          # If the body is being deferred, then terminate afterward.
          if body.respond_to?(:callback) && body.respond_to?(:errback)
            body.callback { terminate }
            body.errback { terminate }
          else
            # Don't terminate the response if we're going async.
            terminate unless response && response.first == AsyncResponse.first
          end
        end
        
        def terminate
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