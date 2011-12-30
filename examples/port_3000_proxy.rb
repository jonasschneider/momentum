require "momentum"
EM.run {
  Momentum.start(Momentum::Backend::Proxy.new('localhost', 3000))
}