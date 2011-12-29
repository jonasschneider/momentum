require 'thin/backends/base'
require 'spdy'
require 'eventmachine'
require 'em-http'

require "logger"

require "momentum/version"
require "momentum/stream"
require "momentum/request"
require "momentum/session"
require "momentum/thin_backend"

require "momentum/backend/base"
require "momentum/backend/local"
require "momentum/backend/proxy"

module Momentum
  def self.start(app)
    EventMachine.start unless EventMachine.reactor_running?
    
    EventMachine.start_server('localhost', 5555, Momentum::Session) do |sess|
      sess.backend = Backend::Local.new(app)
    end
  end
  
  def self.start_proxy(host, port)
    EventMachine.start unless EventMachine.reactor_running?
    
    EventMachine.start_server('localhost', 5555, Momentum::Session) do |sess|
      sess.backend = Backend::Proxy.new(host, port)
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