require "momentum"

app = Rack::Server.new.app # load config.ru

SOCKET = '/tmp/momentum-test'
fork do
  Momentum::Adapters::Accelerate::Windigo.new(app, listeners: SOCKET, worker_processes: 4).start.join
end

EM.run {
  Momentum.start(Momentum::Adapters::Accelerate.new(SOCKET))
  puts "Momentum running"
}