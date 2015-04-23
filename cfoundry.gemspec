# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cfoundry/version"

Gem::Specification.new do |s|
  s.name        = "cfoundry"
  s.version     = CFoundry::VERSION.dup
  s.authors     = ["Cloud Foundry Team", "Alex Suraci"]
  s.license       = "Apache 2.0"
  s.email       = ["vcap-dev@googlegroups.com"]
  s.homepage    = "http://github.com/cloudfoundry/cfoundry"
  s.summary     = %q{
    High-level library for working with the Cloud Foundry API.
  }

  s.rubyforge_project = "cfoundry"

  s.files         = %w[LICENSE Rakefile] + Dir.glob("lib/**/*") + \
                      Dir.glob("vendor/errors/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = %w[lib]

  s.add_dependency "activemodel", "<5.0.0", ">= 3.2.13"
  s.add_dependency "cf-uaa-lib", "~> 2.0.1"
  s.add_dependency "multi_json", "~> 1.7"
  s.add_dependency "multipart-post", "~> 1.1"
  s.add_dependency "zip-zip", "~> 0.3"

  s.add_development_dependency "anchorman"
  s.add_development_dependency "factory_girl"
  s.add_development_dependency "gem-release"
  s.add_development_dependency "json_pure", "~> 1.8"
  s.add_development_dependency "rake", ">= 0.9"
  s.add_development_dependency "rspec", "~> 2.14"
  s.add_development_dependency "shoulda-matchers", "~> 1.5.6"
  s.add_development_dependency "timecop", "~> 0.6.1"
  s.add_development_dependency "webmock", "~> 1.9"
  s.add_development_dependency "putsinator"
end
