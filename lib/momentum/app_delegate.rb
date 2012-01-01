module Momentum
  class AppDelegate
    attr_reader :momentum_request

    def initialize(momentum_request = nil, &block)
      @momentum_request = momentum_request
      @callback = block if block_given?
    end
    
    def push(url)
      @callback.call(:push, url) if @callback
    end
  end
end