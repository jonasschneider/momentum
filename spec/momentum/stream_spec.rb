require File.expand_path("../../support/helpers", __FILE__)

require "momentum"

describe Momentum::Stream do
  let(:session) { double('Session').tap{|s|s.stub(:logger).and_return(double(:debug => true))} }

  let(:stream) { Momentum::Stream.new 1, session }

  describe "#write" do
    it "writes to the stream" do
      data = 'ohai'
      correct_size = data.size
 
      session.should_receive(:send_data_frame) do |id, data, fin|
        data.size.should == correct_size
      end

      stream.write data
    end

    it "works with multibyte chars" do
      data = 'tschüss'
      correct_size = data.size + 1 # the ü takes two bytes

      session.should_receive(:send_data_frame) do |id, data, fin|
        data.size.should == correct_size
      end

      stream.write data
    end
  end
end