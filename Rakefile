require "rake"
require "rspec/core/rake_task"
Dir.glob("lib/tasks/**/*").sort.each { |ext| load(ext) }

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "cfoundry/version"


RSpec::Core::RakeTask.new(:spec)
task :default => :spec
