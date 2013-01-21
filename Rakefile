require "rake"
require "auto_tagger"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "cfoundry/version"

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

namespace :release do
  DEPENDENTS = %w[
    vmc/vmc.gemspec
    vmc-plugins/admin/admin-vmc-plugin.gemspec
    vmc-plugins/tunnel/tunnel-vmc-plugin.gemspec
    vmc-plugins/tunnel-dummy/tunnel-dummy-vmc-plugin.gemspec
  ].freeze

  def bump_dependent(file, dep, ver)
    puts "Bumping #{dep} to #{ver} in #{file}"

    old = File.read(file)
    new = old.sub(/(\.add.+#{dep}\D+)[^'"]+(.+)/, "\\1#{ver}\\2")

    File.open(file, "w") { |io| io.print new }
  end
  
  task :bump_dependents do
    DEPENDENTS.each do |dep|
      bump_dependent(File.join("../../#{dep}", __FILE__), "cfoundry", CFoundry::VERSION)
    end
  end
end
