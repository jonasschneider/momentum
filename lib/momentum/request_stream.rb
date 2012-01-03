module Momentum
  class RequestStream < Stream
    def initialize(stream_id, session, headers, backend)
      super(stream_id, session)
      @session, @backend = session, backend
      @request = Request.new(headers: headers)
      @request_received_at = Time.now
      logger.info "[#{@stream_id}] got a request to #{@request.uri}"
    end

    def process_request!
      reply = @backend.prepare(@request)

      reply.on_push do |url|
        handle_push(url)
      end

      reply.on_headers do |headers|
        @session.send_syn_reply @stream_id, headers
        logger.debug "[#{@stream_id}] SYN_REPLY sent after #{(Time.now - @request_received_at).to_f}s"
      end

      reply.on_body do |chunk|
        send_data chunk
      end

      reply.on_complete do
        logger.debug "[#{@stream_id}] Request completed, took #{ (Time.now - @request_received_at).to_f}s start-to-finish"
        eof!
      end

      reply.dispatch!
    end

    protected

    def handle_push(url)
      logger.debug "[#{@stream_id}] Server Push of #{url} requested"
      parsed = URI.parse(url)
      original_uri = @request.uri.dup
      original_uri.host = parsed.host if parsed.host
      original_uri.scheme = parsed.scheme if parsed.scheme
      original_uri.path = parsed.path if parsed.path
      resource_stream_id = @session.send_syn_stream(@stream_id,  { 'host' => original_uri.host, 'scheme' => original_uri.scheme, 'path' => original_uri.path })



      backend_headers = @request.headers.dup
      backend_headers['host'] = original_uri.host
      backend_headers['scheme'] = original_uri.scheme
      backend_headers['path'] = original_uri.path
      backend_headers.delete 'url' # Fu, chrome

      push_request = Request.new(headers: backend_headers)
      push_backend_reply = @backend.prepare(push_request)

      push_backend_reply.on_headers do |headers|
        @session.send_headers resource_stream_id, headers
        logger.debug "[#{@resource_stream_id}] headers came in from backend"
      end
      push_stream = Stream.new resource_stream_id, @session

      push_backend_reply.on_body do |chunk|
        push_stream.send_data chunk
      end

      push_backend_reply.on_complete do
        logger.debug "[#{@resource_stream_id}] Push Request completed"
        push_stream.eof!
      end

      push_backend_reply.dispatch!
    end

    def logger
      @session.logger
    end
  end
end