module Momentum
  class Backend
    class Response
      AsyncResponse = [-1, {}, []].freeze
      
      def on_headers(&blk)
        @on_headers = blk
      end
      
      def on_body(&blk)
        @on_body = blk
      end
      
      def on_complete(&blk)
        @on_complete = blk
      end
      
      def on_push(&blk)
        @on_push = blk
      end

      def initialize(app, req)
        @app = app
        @req = req
      end

      def dispatch!
        env = @req.to_rack_env
        env['async.callback'] = lambda {|response|
          process_response(response)
        }
        env['spdy'] = build_delegate
        
        response = AsyncResponse
        catch(:async)  do
          response = @app.call(env)
        end
        process_response(response)
      end

      def build_delegate
        Momentum::AppDelegate.new(@req) do |what, push_url|
          case what
          when :push
            @on_push.call(push_url) if @on_push
          else
            raise "Unknown callback #{what}"
          end
        end
      end

      protected

      def process_response(response)
        return if response.first == AsyncResponse.first
        
        status, headers, body = response
        headers['status'] = status.to_s
        headers['version'] = 'HTTP/1.1'
        @on_headers.call cleanup_response_headers(headers) if @on_headers
        
        body.each do |chunk|
          @on_body.call(chunk.to_s) if @on_body
        end
        
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
      
      def cleanup_response_headers(headers)
        hdrs = headers.inject(Hash.new) do |hash,kv|
          hash[kv[0].downcase.gsub('_', '-')] = kv[1]
          hash
        end
        #if cookie = hdrs['Set-Cookie'] and cookie.respond_to?(:join)
        #  hdrs['Set-Cookie'] = cookie.join(', ')
        #end
        hdrs.each {|k,v| hdrs[k] = v.first if v.respond_to?(:first)}
        # Remove junk headers
        hdrs.reject! {|hdr| hdr.start_with?('X-')}
        hdrs.reject! {|hdr| REJECTED_HEADERS.include? hdr}
        hdrs.reject! {|hdr,val| val.empty?}
        hdrs
      end
    end
    
    def initialize(app)
      @app = app
    end
    
    def prepare(req)
      Response.new(@app, req)
    end
  end
end