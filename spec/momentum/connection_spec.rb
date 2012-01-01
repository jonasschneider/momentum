require File.expand_path("../../support/helpers", __FILE__)

require File.expand_path("../../support/blocking_spdy_client", __FILE__)
require "momentum"
require "em-synchrony"

describe Momentum::Connection do
  it "sends a notice to HTTP clients" do
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ['ohai']] }

    EM.synchrony do
      Momentum.start(app)
      url = 'http://localhost:5555/'
      s = EventMachine::Synchrony::TCPSocket.new 'localhost', 5555
      s.send("GET / HTTP/1.1\nHost: localhost\n\n")
      response = s.read

      response.should == Momentum::Connection::HTTP_RESPONSE

      EM.stop
    end
  end
end