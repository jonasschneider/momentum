require File.expand_path("../../support/helpers", __FILE__)
require File.expand_path("../../support/backend_examples", __FILE__)

require "momentum"

describe Momentum::Backend do
  let(:app) { lambda { |env| [given_response_status, given_response_headers, [given_response_body]] } }
  let(:backend) { Momentum::Backend.new(app) }

  include_examples "Momentum backend"

  context "env['momentum.request']" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, [env['momentum.request'].inspect]] } }
    
    it "contains the request" do
      response_body.should == request.inspect
    end
  end

  context "env['async.callback']" do
    class DeferrableBody
      include EventMachine::Deferrable
     
      def call(body)
        body.each do |chunk|
          @body_callback.call(chunk)
        end
      end
     
      def each &block
        @body_callback = block
      end
    end

    let(:app) do lambda { |env|
      EM.next_tick do
        b = DeferrableBody.new
        env['async.callback'].call [200, { "Content-type" => "text/plain" }, b]
        b.call ['1']
        EM.next_tick do
          b.call ['2']
          EM.next_tick do
            b.call ['3']
            b.succeed
          end
        end
      end
      throw :async
    }; end
    
    it "supports deferred bodies" do
      response_body.should == '123'
    end
  end
end