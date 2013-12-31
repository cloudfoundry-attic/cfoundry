require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::AppUsageEvents do
  describe ".succeed_to_load_many" do
    let(:url) { "http://example.com/v2/app_usage_events" }
    subject { CcApiStub::AppUsageEvents.succeed_to_load_many }

    it_behaves_like "a stubbed get request"
  end
end
