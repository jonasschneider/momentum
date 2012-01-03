require File.expand_path("../../spec/support/helpers", __FILE__)
require File.expand_path("../../spec/support/blocking_spdy_client", __FILE__)

require "momentum"
require "em-synchrony"
require "benchmark"
Momentum.logger.level = Logger::WARN

N = 100

puts "N = #{N}"

def benchmark(name)
  print name.ljust(25)
  start_time = Time.now
  yield
  end_time = Time.now
  diff = (end_time - start_time).to_f
  puts "%f.4 (%f.4 total) " % [diff/N, diff]
end

def run_tests(name)
  puts
  puts "=== #{name}".ljust(55, '=')

  EM.synchrony do
    Momentum.start(yield)

    benchmark 'Multiple connections' do
      N.times do
        c = BlockingSPDYClient.new('127.0.0.1', 5555)
        c.request '/'
        c.read_packet
        c.read_packet
        c.read_packet
        c.close
      end
    end

    benchmark 'Single connection' do
      c = BlockingSPDYClient.new('127.0.0.1', 5555)
      N.times do
        c.request '/'
        c.read_packet
        c.read_packet
        c.read_packet
      end
      c.close
    end

    EM.stop
  end
end

app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ['text']] }

run_tests 'No adapter' do
  app
end

run_tests 'Defer adapter' do
  Momentum::Adapters::Defer.new(app)
end