require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"

describe Momentum::Backend::Local do
  let(:backend) { Momentum::Backend::Local.new(app) }

  include_examples "Momentum backend"
end