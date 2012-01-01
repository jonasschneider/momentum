require File.expand_path("../../support/helpers", __FILE__)

require "momentum"

describe Momentum::AppDelegate do
  context "without push callback" do
    subject { Momentum::AppDelegate.new }

    it "does nothing on push" do
      subject.push('/test.js')
    end
  end

  context "with push callback" do
    subject { Momentum::AppDelegate.new do
      @called = true
     end }

    it "works" do
      subject.push('/test.js')
      @called.should == true
    end
  end
end