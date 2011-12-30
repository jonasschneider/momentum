require "momentum"

EM.run {
  Momentum.start(Momentum::Adapters::Proxy.new('localhost', 3000))
}