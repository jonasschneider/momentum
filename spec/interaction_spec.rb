require File.expand_path("../support/helpers", __FILE__)

require File.expand_path("../support/blocking_spdy_client", __FILE__)

require "momentum"
require "em-synchrony"

describe Momentum do
  context "Cool client" do
    let(:response) { 'test' }
    it "works" do
      app = lambda { |env| [200, {"Content-Type" => "text/plain"}, [response]] }
      Timeout.timeout(3) do
        EM.synchrony do
          Momentum.start(Momentum::Backend.new(app))

          c = BlockingSPDYClient.new('localhost', 5555)
          c.request '/'

          p = c.read_packet
          p.class.should == SPDY::Protocol::Control::SynReply
          p.header.version.should == 2 # FIXME: v3?
          p.header.type.should == 2
          p.header.flags.should == 0
          p.header.len.should == 45
          p.uncompressed_data.to_h.should == {"content-type"=>"text/plain", "status"=>"200", "version"=>"HTTP/1.1"}

          data = c.read_packet
          data.class.should == SPDY::Protocol::Data::Frame
          data.stream_id.should == 1
          data.flags.should == 0
          data.len.should == 4
          data.data.should == response

          fin = c.read_packet
          fin.class.should == SPDY::Protocol::Data::Frame
          fin.stream_id.should == 1
          fin.flags.should == 1
          fin.len.should == 0
          
          EM.stop
        end
      end
    end
  end
end