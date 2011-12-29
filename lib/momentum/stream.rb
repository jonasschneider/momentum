module Momentum
  class Stream
    attr_reader :options
    
    # options[:zlib_session] is the SPDY::Zlib session
    def initialize(options)
      @options = options
    end
    
    def syn_reply
      sr = SPDY::Protocol::Control::SynReply.new({:zlib_session => options[:zlib]})
      
      headers = {'Content-Type' => 'text/plain', 'status' => '200 OK', 'version' => 'HTTP/1.1'}
      sr.create({:stream_id => options[:stream_id], :headers => headers})
    end
    
    def data_frame(data)
      d = SPDY::Protocol::Data::Frame.new
      d.create(:stream_id => options[:stream_id], :data => data)
    end
    
    def fin_frame
      d = SPDY::Protocol::Data::Frame.new
      d.create(:stream_id => options[:stream_id], :flags => 1)
    end
  end
end