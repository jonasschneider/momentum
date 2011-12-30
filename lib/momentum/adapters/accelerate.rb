module Momentum
  module Adapters
    class Accelerate
      def initialize(app)
        Windigo.new(app, options).start
      end
      def call(env)
        # okay
      end
    end
  end
end