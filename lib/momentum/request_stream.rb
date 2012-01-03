module Momentum
  class RequestStream < Stream
    def initialize(stream_id, session, headers, backend)
      super(stream_id, session)
      @session, @backend = session, backend
      req = Request.new(headers: headers)
      logger.info "[#{stream_id}] got a request to #{req.uri}"
      request_received_at = Time.now

      send_buffer = ''

      #@streams << req
      @reply = @backend.prepare(req)

      @reply.on_push do |url|
        logger.debug "[#{stream_id}] Server Push of #{url} requested"
        parsed = URI.parse(url)
        original_uri = req.uri.dup
        original_uri.host = parsed.host if parsed.host
        original_uri.scheme = parsed.scheme if parsed.scheme
        original_uri.path = parsed.path if parsed.path
        resource_stream_id = @session.send_syn_stream(stream_id,  { 'host' => original_uri.host, 'scheme' => original_uri.scheme, 'path' => original_uri.path })

        backend_headers = headers.dup
        backend_headers['host'] = original_uri.host
        backend_headers['scheme'] = original_uri.scheme
        backend_headers['path'] = original_uri.path
        backend_headers.delete 'url' # Fu, chrome

        push_request = Request.new(headers: backend_headers)
        push_backend_reply = @backend.prepare(push_request)

        push_backend_reply.on_headers do |headers|
          @session.send_headers resource_stream_id, headers
          logger.debug "[#{resource_stream_id}] headers came in from backend"
        end
        push_stream = Stream.new resource_stream_id, @session

        push_backend_reply.on_body do |chunk|
          push_stream.write chunk
        end

        push_backend_reply.on_complete do
          logger.debug "[#{resource_stream_id}] Push Request completed"
          push_stream.eof!
        end

        push_backend_reply.dispatch!
      end

      @reply.on_headers do |headers|
        @session.send_syn_reply stream_id, headers
        logger.debug "[#{stream_id}] SYN_REPLY sent after #{(Time.now - request_received_at).to_f}s"
      end
      stream = Stream.new stream_id, @session

      @reply.on_body do |chunk|
        stream.write chunk
      end

      @reply.on_complete do
        logger.debug "[#{stream_id}] Request completed, took #{ (Time.now - request_received_at).to_f}s start-to-finish"
        stream.eof!
      end
    end

    def process_request!
      @reply.dispatch!
    end

    def logger
      @session.logger
    end
  end
end