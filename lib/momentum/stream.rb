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
    
    def write(data)
      @data << data
      send_data
    end
    
    protected
    
    def send_data
      return if @data.empty?
      chunk = @data.slice!(0, CHUNK_SIZE)
      if @data.empty?
        send_body chunk, @eof
      else
        unless @delayed_write_in_progress
          @delayed_write_in_progress = true
          EM.next_tick do
            @delayed_write_in_progress = false
            send_data
          end
        end
        send_body chunk
      end
    end
    
    def send_body(chunk, fin = false)
      @session.send_data_frame @stream_id, chunk, fin
      @sent_bytes += chunk.size
      @session.logger.debug "Stream #{@stream_id} send_body (chunk=#{chunk.size}, fin=#{fin}), #{@sent_bytes} bytes sent"
    end
  end
end