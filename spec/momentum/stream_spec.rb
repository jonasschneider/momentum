require File.expand_path("../../support/helpers", __FILE__)

require "momentum"

describe Momentum::Stream do
  let(:session) { double('Session').tap{|s|s.stub(:logger).and_return(double(:debug => true))} }

  let(:stream) { Momentum::Stream.new 1, session }

  describe "#send_data" do
    it "writes to the stream" do
      data = 'ohai'
      correct_size = data.size

      session.should_receive(:send_data_frame) do |id, data, fin|
        data.size.should == correct_size
      end

      stream.send_data data
    end

    it "works with multibyte chars" do
      data = 'tschüss'
      correct_size = data.size + 1 # the ü takes two bytes

      session.should_receive(:send_data_frame) do |id, data, fin|
        data.size.should == correct_size
      end

      stream.send_data data
    end

    context "when the data is larger than the chunk size" do
      let(:chunk_size) { Momentum::Stream::CHUNK_SIZE }
      let(:one_chunk) { 'x'*chunk_size }
      let(:data_to_send) { one_chunk*3 }

      it "sends the response in multiple data frames" do
        times_called = 0
        stream.stub(:send_data_frame) do
          times_called += 1
          EM.stop if times_called == 3
        end
        Timeout.timeout(2) do
          EM.run do
            stream.send_data data_to_send
          end
        end
        times_called.should == 3
      end
    end
  end
end