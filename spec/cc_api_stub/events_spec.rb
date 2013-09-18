require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Events do
  describe ".succeed_to_load_many" do
    let(:url) { "http://example.com/v2/events" }
    subject { CcApiStub::Events.succeed_to_load_many }

    it_behaves_like "a stubbed get request"
  end
end
