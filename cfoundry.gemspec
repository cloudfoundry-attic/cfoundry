# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cfoundry/version"

Gem::Specification.new do |s|
  s.name        = "cfoundry"
  s.version     = CFoundry::VERSION.dup
  s.authors     = ["Cloud Foundry Team", "Alex Suraci"]
  s.email       = ["vcap-dev@googlegroups.com"]
  s.homepage    = "http://github.com/cloudfoundry/vmc-lib"
  s.summary     = %q{
    High-level library for working with the Cloud Foundry API.
  }

  s.rubyforge_project = "cfoundry"

  s.files         = %w[LICENSE Rakefile] + Dir.glob("lib/**/*") + \
                      Dir.glob("vendor/errors/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = %w[lib]

  s.add_dependency "multipart-post", "~> 1.1"
  s.add_dependency "multi_json", "~> 1.3"
  s.add_dependency "rubyzip", "~> 0.9"
  s.add_dependency "cf-uaa-lib", "~> 1.3.8"

  s.add_development_dependency "rake", "~> 0.9"
  s.add_development_dependency "rspec", "~> 2.11"
  s.add_development_dependency "webmock", "~> 1.9"
  s.add_development_dependency "rr", "~> 1.0"
  s.add_development_dependency "gem-release"
  s.add_development_dependency "timecop"
end
