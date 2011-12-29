module Momentum
  class Request
    attr_accessor :spdy_info
    
    PATH_INFO         = 'PATH_INFO'.freeze
    QUERY_STRING      = 'QUERY_STRING'.freeze
    REQUEST_METHOD    = 'REQUEST_METHOD'.freeze
    SERVER_NAME       = 'SERVER_NAME'.freeze
    SERVER_PORT       = 'SERVER_PORT'.freeze
    SERVER_SOFTWARE   = 'SERVER_SOFTWARE'.freeze
    HTTP_VERSION      = 'HTTP_VERSION'.freeze
    REMOTE_ADDR       = 'REMOTE_ADDR'.freeze
  
    RACK_INPUT        = 'rack.input'.freeze
    RACK_VERSION      = 'rack.version'.freeze
    RACK_ERRORS       = 'rack.errors'.freeze
    RACK_MULTITHREAD  = 'rack.multithread'.freeze
    RACK_MULTIPROCESS = 'rack.multiprocess'.freeze
    RACK_RUN_ONCE     = 'rack.run_once'.freeze
    RACK_SCHEME       = 'rack.url_scheme'.freeze

    # spdy_info[:headers] is a hash mapping strings to strings, containing the http headers from the SPDY request.
    # spdy_info[:remote_addr] is the remote IP address
    def initialize(spdy_info)
      @spdy_info = spdy_info
    end
    
    def to_rack_env
      @env ||= begin
        env = {
          REQUEST_METHOD    => spdy_info[:headers]['method'],
          SERVER_SOFTWARE   => 'Momentum',
          HTTP_VERSION      => '1.1',
          REMOTE_ADDR       => spdy_info[:remote_addr],

          RACK_VERSION      => [1,1],
          RACK_ERRORS       => STDERR,
          RACK_SCHEME       => 'http', # TODO: SSL
          RACK_MULTITHREAD  => true,
          RACK_MULTIPROCESS => false,
          RACK_RUN_ONCE     => false,

          SERVER_NAME       => uri.host || 'localhost',
          SERVER_PORT       => uri.port.to_s,
          PATH_INFO         => uri.path,
          QUERY_STRING      => uri.query || '',
          RACK_INPUT        => StringIO.new(spdy_info[:body] || ''.force_encoding('ASCII-8BIT'))
        }
        spdy_info[:headers].each do |k,v|
          key = k.gsub('-', '_').upcase
          unless key == 'CONTENT_TYPE' || key == 'CONTENT_LENGTH'
            key = 'HTTP_' + key
          end
          env[key] = v
        end
        env
      end
    end
    
    def uri
      @uri ||= URI.parse(spdy_info[:headers]['url'])
    end
  end
end