require "rake"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "cfoundry/version"

RSpec::Core::RakeTask.new(:spec)
task :default => :spec
