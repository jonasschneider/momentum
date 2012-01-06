require File.expand_path("../../support/helpers", __FILE__)

require "momentum"
require "em-synchrony"
require "awesome_print"

require File.expand_path("../../support/blocking_spdy_client", __FILE__)
require File.expand_path("../../support/dumb_spdy_client", __FILE__)
require File.expand_path("../../support/dummy_backend_response", __FILE__)


class EventMachine::Connection
  alias_method :send_data_without_record, :send_data
  attr_accessor :__sent_data

  def send_data(data)
    @__sent_data ||= ''
    @__sent_data << data
    send_data_without_record(data)
  end
end

describe Momentum::Connection do
  let(:backend) { stub }
  let(:connection) { Momentum::Connection.new(1).tap{|c|c.backend = backend} }

  def connect
    EM.run {
      yield
      EM.stop
    }
  end

  def send(data)
    connection.receive_data(data.force_encoding('ascii-8bit'))
  end

  def received_data
    connection.__sent_data
  end

  def should_receive(data)
    received_data.inspect.should == data.inspect
    connection.__sent_data = ''
  end

  it "sends a notice to HTTP clients" do
    connect do
      send "GET / HTTP/1.1\nHost: localhost\n\n"
      should_receive Momentum::Connection::HTTP_RESPONSE
    end
  end

  it "adds sent DATA frames to the request body" do
    connect do
      zlib = SPDY::Zlib.new

      pckt = SPDY::Protocol::Control::SynStream.new({:zlib_session => zlib})
      send pckt.create({:stream_id => 0, :headers => {}}).to_binary_s

      Momentum::RequestStream.any_instance.should_receive(:add_body).with('ohai')
      Momentum::RequestStream.any_instance.should_receive(:add_body).with(' there')

      data = SPDY::Protocol::Data::Frame.new({:zlib_session => zlib})
      send data.create({:stream_id => 0, :data => 'ohai'}).to_binary_s

      data = SPDY::Protocol::Data::Frame.new({:zlib_session => zlib})
      send data.create({:stream_id => 0, :data => ' there'}).to_binary_s
    end
  end
end