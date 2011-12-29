# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "momentum/version"

Gem::Specification.new do |s|
  s.name        = "momentum"
  s.version     = Momentum::VERSION
  s.authors     = ["Jonas Schneider"]
  s.email       = ["mail@jonasschneider.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "momentum"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "rack"
  s.add_runtime_dependency "eventmachine"
  s.add_runtime_dependency "spdy"
  s.add_runtime_dependency "thin"
end
