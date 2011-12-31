module Momentum
  module Adapters
    class Defer
      def initialize(app)
        @app = app
        EM.defer proc{}, proc{}
      end
      
      def call(env)
        dup._call(env)
      end
      
      def _call(env)
        @env = env
        EM.defer method(:run_app), method(:send_response)
        
        throw(:async)
      end
      
      def run_app
        @process_start = Time.now
        r = @app.call(@env)
        #Momentum.logger.debug "[#{@env['spdy'].momentum_request.spdy_info[:stream_id]}] app processing took #{(Time.now - @process_start).to_f} secs"
        r
      end
      
      def send_response(response)
        buffered_body = []
        response[2].each do |chunk|
          buffered_body << chunk
        end
        response[2] = buffered_body
        @env['async.callback'].call response
      end
    end
  end
end