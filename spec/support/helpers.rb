# -*- coding: ascii-8bit -*-

ENV["RACK_ENV"] = 'test'
require "bundler"
Bundler.setup
require 'rspec'

require 'eventmachine'
require 'em-http'

require 'socket'
require 'timeout'

def is_socket_open?(path)
  begin
    Timeout::timeout(1) do
      begin
        s = UNIXSocket.new(path)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::ENOENT
        return false
      end
    end
  rescue Timeout::Error
  end

  return false
end

def is_port_open?(ip, port)
  begin
    Timeout::timeout(1) do
      begin
        s = TCPSocket.new(ip, port)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        return false
      end
    end
  rescue Timeout::Error
  end

  return false
end

GET_REQUEST = "\x80\x02\x00\x01\x01\x00\x01p\x00\x00\x00\x01\x00\x00\x00\x00\x00\x008\xEA\xDF\xA2Q\xB2b\xE0f`\x83\xA4\x17\x06{\xB8\vu0,\xD6\xAE@\x17\xCD\xCD\xB1.\xB45\xD0\xB3\xD4\xD1\xD2\xD7\x02\xB3,\x18\xF8Ps,\x83\x9Cg\xB0?\xD4=:`\a\x81\xD5\x99\xEB@\xD4\e3\xF0\xA3\xE5i\x06A\x90\x8Bu\xA0N\xD6)NI\xCE\x80\xAB\x81%\x03\x06\xE5\x94T]\x17W\xA0\"\x88\xA5:\xA9y\xBA\xA1\xC1`\xB6\x19\x90\rf\x980\xB0A\xE2\x93\xC1\aX\x9Ad\xEB\x15\xA7\x16\x83\xBCk\xEB\xE4\x98a\xEE\x94\x95\xEF\x1D\x19\x1ET\x92\x18n\x92\xE9\x15\x12\x95\xE9\x97\e\x96\xE5\x9B\x15X\xE9\x97\x95n\xE8\e\xEEY\x05\x90o\xAE[\x86\xAF\xBB_VdV\xA8\x89oHN\xA6oV\xB2\xB1\xBFKz\x95\xAA\x81#\x03\v\xA88a\xE0*\xC9,I\xCC\xB3\x02fb\x03\x06\xB6\\`\x11\x96\x9F\xC2\xC0\xEC\xEE\x1A\xC2\xC0V\fL\xF5\xB9\xA9@e%%\x05\f\xCC\xA0\xD0e\xD4g\xE0B\x14\t\f\x99\xBE\xF9U\x9999\x89\xFA\xA6z\x06\n\x1A\xE1\x99y)\xF9\xE5\xC5\n~!\nfz\x86\xD6\n\xE1\xFE\xE1f&\x9A\n\x8E\xC0PN\rOM\xF2\xCE,\xD1756\xD53W\xD0\xF0\xF6\b\x01\xC8\xD7GG!'3;U\xC1=59;_S\xC19\x03X\xBC\xA5\xEA\e\x9A\xE9\x01\xE3\xC0\xD0H\xCF\xCCX!81-\xB1(\x13\xA2\x87\x81\x1D\x1A\xC7\f\x1C\xB0\xA8\a\x00\x00\x00\xFF\xFF"