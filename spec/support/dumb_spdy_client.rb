class DumbSPDYClient < EventMachine::Connection
  class << self
    attr_accessor :body, :body_chunk_count, :headers
  end
  
  def post_init
   @parser = ::SPDY::Parser.new
   @body = ""
   @body_chunk_count = 0
   
   @parser.on_body do |id, data|
     @body << data
     @body_chunk_count += 1
   end
   
   @parser.on_headers_complete do |a, s, d, headers|
     DumbSPDYClient.headers = headers
   end
     
   @parser.on_message_complete do
     DumbSPDYClient.body = @body
     DumbSPDYClient.body_chunk_count = @body_chunk_count
     EventMachine::stop_event_loop
   end
   
   send_data GET_REQUEST
   
  rescue Exception => e
    puts e.inspect
  end
  
  def receive_data data
    @parser << data
  end
end