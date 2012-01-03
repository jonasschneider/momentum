module Momentum
  class Stream
    CHUNK_SIZE = 4096

    def initialize(stream_id, session)
      @stream_id, @session = stream_id, session
      @send_buffer = ''
      @eof = false
    end

    def eof!
      if @send_buffer.length > 0
        @eof = true
      else
        @session.send_fin @stream_id
      end
    end

    def send_data(data)
      @send_buffer << data.force_encoding('ASCII-8BIT')
      send_data_chunk
    end

    protected

    def send_data_chunk
      return if @send_buffer.empty?
      chunk = @send_buffer.slice!(0, CHUNK_SIZE)
      if @send_buffer.empty?
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
      @session.logger.debug "< FIN stream=#{@stream_id}" if fin
    end
  end
end