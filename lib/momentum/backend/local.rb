module Momentum
  module Backend
    class Local
      def initialize(app)
        @app = app
      end
      
      def dispatch(req)
        @app.call(req.to_rack_env)
      end
    end
  end
end