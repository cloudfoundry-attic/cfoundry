require "rspec"
require "cfoundry"
require "webmock/rspec"

Dir[File.expand_path('../{support,fakes}/**/*.rb', __FILE__)].each do |file|
  require file
end

def random_string(tag = "random")
  sprintf("%s-%x", tag, rand(10 ** 6))
end

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.mock_with :rr
end