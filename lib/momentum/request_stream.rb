module Momentum
  class RequestStream < Stream
    def initialize(stream_id, session, backend)
      super(stream_id, session)
      @session, @backend = session, backend
      @headers = {}
      @body = ''
      @request_received_at = Time.now
    end

    def add_headers(headers)
      @headers.merge! headers
    end

    def add_body(chunk)
      @body << chunk
    end

    def process_request!
      @request = Request.new(headers: @headers, body: @body, remote_addr: @session.peer)

      logger.info "[#{@stream_id}] got a request to #{@request.uri}"
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

    # TODO draft3: send :host, :scheme, :path instead of :url
    # TODO: Set unidirectional flag
    def handle_push(url_text)
      parsed = URI.parse(url_text)

      push_url = @request.uri.dup
      push_url.host = parsed.host if parsed.host
      push_url.scheme = parsed.scheme if parsed.scheme
      push_url.path = parsed.path if parsed.path

      logger.debug "[#{@stream_id}] Server Push of #{url_text} requested, push URL is #{push_url}  (path #{push_url.path})"

      resource_stream_id = @session.send_syn_stream(@stream_id,  { 'url' => push_url.to_s })

      backend_headers = @request.headers.dup
      backend_headers.delete 'path'
      backend_headers['url'] = push_url.path

      push_request = Request.new(headers: backend_headers)
      push_backend_reply = @backend.prepare(push_request)

      push_backend_reply.on_headers do |headers|
        @session.send_headers resource_stream_id, headers
        logger.debug "[#{resource_stream_id}] headers came in from backend"
      end
      push_stream = Stream.new resource_stream_id, @session

      push_backend_reply.on_body do |chunk|
        push_stream.send_data chunk
      end

      push_backend_reply.on_complete do
        logger.debug "[#{resource_stream_id}] Push Request completed"
        push_stream.eof!
      end

      push_backend_reply.dispatch!
    end

    def logger
      @session.logger
    end
  end
end