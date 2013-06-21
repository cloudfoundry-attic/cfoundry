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

require "support/shared_examples/cc_api_stub_request_examples"
require "support/shared_examples/client_login_examples"
require "support/shared_examples/model_summary_examples"
require "support/factory_girl"
require "support/test_model_builder"

RSpec.configure do |c|
end
