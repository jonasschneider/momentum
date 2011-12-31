require "momentum"

app = Rack::Server.new.app # load config.ru

EM.run {
  Momentum.start(Momentum::Adapters::Defer.new(app))
  puts "Momentum running"
}