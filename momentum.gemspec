# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "momentum/version"

Gem::Specification.new do |s|
  s.name        = "momentum"
  s.version     = Momentum::VERSION
  s.authors     = ["Jonas Schneider"]
  s.email       = ["mail@jonasschneider.com"]
  s.homepage    = ""
  s.summary     = %q{A SPDY Server for Rack apps.}
  s.description = %q{Momentum is a SPDY server that aims to be drop-in compatible with existing Rack apps.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"
  s.add_development_dependency "webmock"
  s.add_development_dependency "em-synchrony", "~> 0.2.0"

  s.add_runtime_dependency "rack"
  s.add_runtime_dependency "eventmachine", "~> 1.0.0.beta4"
  s.add_runtime_dependency "em-http-request"
  s.add_runtime_dependency "unicorn"

  # spdy deps
  s.add_dependency "bindata"
  s.add_dependency "ffi-zlib"
end
