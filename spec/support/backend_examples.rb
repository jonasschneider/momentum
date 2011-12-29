require "timeout"

shared_examples "Momentum backend" do 
  describe "after making a request" do
    let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, [response]] } }
    let(:response) { 'hello from my rack app' }
    
    let(:rack_env) { { "a" => "b" } }
    
    let(:headers) { { :url => '/' } }

    let(:request) { stub(
      :headers => headers,
      :uri => URI.parse('/'),
      :to_rack_env => rack_env
    ) }
    
    let(:reply) { backend.prepare(request) }
    
    def dispatch!
      reply.on_complete do
        EM.stop
      end
      
      Timeout::timeout(2) {
        EM.run do
          reply.dispatch!
        end
      }
    end
    
    def response_body
      ''.tap do |data|
        reply.on_body do |c|
          data << c
        end
        
        dispatch!
      end
    end
    
    context "with additional headers" do
      let(:app) { lambda { |env| [200, {"Content-Type" => "text/plain"}, [env['HTTP_ME_PRO'].inspect]] } }
      let(:headers) { { :url => '/', 'Me-pro' => 'Yup' } }
      let(:rack_env) { { "HTTP_ME_PRO" => 'Yup' } }
      
      it "passes headers" do
        response_body.should == '"Yup"'
      end
    end
    
    describe "#body" do
      it "fetches the response body" do
        response_body.should == response
      end
    end
  end
end