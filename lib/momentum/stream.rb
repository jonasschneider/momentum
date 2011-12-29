module Momentum
  class Stream
    attr_reader :options
    
    # options[:zlib_session] is the SPDY::Zlib session
    def initialize(options)
      @options = options
    end
  end
end