SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "webmock/rspec"

Dir[File.expand_path('../{support,fakes}/**/*.rb', __FILE__)].each do |file|
  require file
end

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.include V1Fake::FakeMethods
  c.mock_with :rr
end