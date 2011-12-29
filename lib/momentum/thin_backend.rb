module Momentum
  class ThinBackend < Thin::Backends::Base
    def initialize(host, port, options)
      @host = host
      @port = port
      super()
    end
    
    def connect
      @signature = EventMachine.start_server(@host, @port, Momentum::Session) do |sess|
        sess.app = server.app
      end
    end
    
    def disconnect
      EventMachine.stop_server(@signature)
    end
    
    def to_s
      "#{@host}:#{@port} (SPDY)"
    end
  end
end