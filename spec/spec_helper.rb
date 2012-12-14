require "rspec"
require "cfoundry"
require "factory_girl"
require "webmock/rspec"

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each do |file|
  require file
end

FactoryGirl.definition_file_paths =
  [File.expand_path("../factories", __FILE__)]

FactoryGirl.find_definitions

RSpec.configure do |c|
  c.mock_with :rr
end
