require "momentum"
EM.run {
  Momentum.start_proxy('localhost', 3000)
}