SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "webmock/rspec"
require "ostruct"
require "timecop"
require "active_support"
require "active_support/core_ext"
require "cc_api_stub"
require "shoulda/matchers/integrations/rspec" # requiring all of shoulda matchers makes test unit run

Dir[File.expand_path('../{support,fakes}/**/*.rb', __FILE__)].each do |file|
  require file
end

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.mock_with :rr
end
