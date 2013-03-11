SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "webmock/rspec"
require "ostruct"
require "timecop"
require "active_support"
require "active_support/core_ext"
require "cc_api_stub"

Dir[File.expand_path('../{support,fakes}/**/*.rb', __FILE__)].each do |file|
  require file
end

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.include V1Fake::FakeMethods
  c.mock_with :rr
end

# There is a bug in Timecop v0.6.0 that tries to use Time.zone class method
# (from ActiveSupport) if it is defined. However, it does not go on to check
# that it is not nil which can happen if you only use the core_ext part of
# ActiveSupport (which we are). There is a pull request on GitHub[1] to fix
# this but until then we're removing the zone class method.
#
# [1]: https://github.com/travisjeffery/timecop/pull/74
class << Time
  remove_method :zone
end
