require 'spdy'
require 'eventmachine'
require 'em-http'

require "logger"

require "momentum/version"
require "momentum/stream"
require "momentum/request"
require "momentum/request_stream"

require "momentum/connection"

require "momentum/app_delegate"
require "momentum/backend"

require "momentum/adapters/proxy"
require "momentum/adapters/defer"

module Momentum
  REJECTED_HEADERS = ['Accept-Ranges', 'Connection', 'P3p', 'Ppserver',
    'Server', 'Transfer-Encoding', 'Vary']

  def self.start(backend_or_app)
    if backend_or_app.respond_to? :prepare
      backend = backend_or_app
    elsif backend_or_app.respond_to? :call
      backend = Momentum::Backend.new(backend_or_app)
    end
    EventMachine.start_server('0.0.0.0', 5555, Momentum::Connection) do |sess|
      sess.backend = backend
    end
  end

  LOG_FORMAT = "%s, [%s] %s\n"
  def self.logger
    @logger ||= begin
      logger = Logger.new(STDERR)
      logger.level = Logger::DEBUG
      logger.formatter = lambda {|severity, datetime, progname, msg|
        time = datetime.strftime("%H:%M:%S.") << "%06d" % datetime.usec
        LOG_FORMAT % [severity[0..0], time, msg]
      }
      logger
    end
  end
end