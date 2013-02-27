require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::ServiceInstances do
  describe ".succeed_to_create" do
    let(:url) { "http://example.com/v2/service_instances" }
    subject { CcApiStub::ServiceInstances.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end

  describe ".succeed_to_load" do
    let(:url) { "http://example.com/v2/service_instances/123" }
    subject { CcApiStub::ServiceInstances.succeed_to_load }

    it_behaves_like "a stubbed get request"
  end
end