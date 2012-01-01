class DummyBackendResponse < Momentum::Backend::Response
  def initialize(options = {})
    @options = options
  end
  
  def dispatch!
    (@options[:pushes] || []).each do |url|
      @on_push.call(url)
    end
    @on_headers.call(@options[:headers] || {})
    @on_body.call(@options[:body] || '')
    @on_complete.call
  end
end