require "rake"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "cfoundry/version"

task :default => "spec"

desc "Run specs"
task "spec" => ["bundler:install", "test:spec"]

task :build do
  sh "gem build cfoundry.gemspec"
end

task :install => :build do
  sh "gem install --local cfoundry-#{CFoundry::VERSION}"
  sh "rm cfoundry-#{CFoundry::VERSION}.gem"
end

task :uninstall do
  sh "gem uninstall cfoundry"
end

task :reinstall => [:uninstall, :install]

task :release => :build do
  sh "gem push cfoundry-#{CFoundry::VERSION}.gem"
end

namespace "bundler" do
  desc "Install gems"
  task "install" do
    sh("bundle install")
  end
end

namespace "test" do
  task "spec" do |t|
    sh("bundle exec rspec")
  end
end
