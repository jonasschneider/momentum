require "ruby-prof"

require File.expand_path("../../spec/support/helpers", __FILE__)
require File.expand_path("../../spec/support/blocking_spdy_client", __FILE__)
require "momentum"
require "em-synchrony"
Momentum.logger.level = Logger::WARN

app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ['text']] }

EM.synchrony do
  Momentum.start(Momentum::Backend.new(app))
  c = BlockingSPDYClient.new('localhost', 5555)

  RubyProf.start
  c.request '/'
  c.read_packet
  c.read_packet
  c.read_packet
  c.close
  res = RubyProf.stop

  printer = RubyProf::GraphHtmlPrinter.new(res)
  printer.print(File.open(File.expand_path("../profile.html", __FILE__), 'w'), {})
  EM.stop
end
puts "Profile written to perf/profile.html."