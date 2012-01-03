module Momentum
  class Stream
    CHUNK_SIZE = 4096
    def initialize(stream_id, session)
      @stream_id, @session = stream_id, session
      @data = ''
      @sent_bytes = 0
      @eof = false
    end
    
    def eof!
      if @data.length > 0
        @eof = true
      else
        @session.send_fin @stream_id
      end
    end
    
    def send_data(data)
      @data << data.force_encoding('ASCII-8BIT')
      send_data_chunk
    end
    
    protected
    
    def send_data_chunk
      return if @data.empty?
      chunk = @data.slice!(0, CHUNK_SIZE)
      if @data.empty?
        send_data_frame chunk, @eof
      else
        unless @chunking_data
          @chunking_data = true
          EM.next_tick do
            @chunking_data = false
            send_data_chunk
          end
        end
        send_data_frame chunk
      end
    end
    
    def send_data_frame(chunk, fin = false)
      @session.send_data_frame @stream_id, chunk, fin
      @sent_bytes += chunk.size
      @session.logger.debug "< FIN stream=#{@stream_id} after #{@sent_bytes} bytes sent" if fin
    end
  end
end