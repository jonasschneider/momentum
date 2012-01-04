require "momentum"

port = ARGV.shift.to_i

if port.zero?
  puts "usage: #{$0} <port_to_proxy>"
  exit
end

EM.run do
  Momentum.start(Momentum::Adapters::Proxy.new('localhost', port))
  puts ">> Momentum running on 0.0.0.0:5555 proxying to localhost:#{port}"
end