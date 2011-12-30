class DummyBackendResponse < Momentum::Backend::Response
  def initialize(options)
    @options = options
  end
  
  def dispatch!
    @on_headers.call(@options[:headers] || {})
    @on_complete.call
  end
end