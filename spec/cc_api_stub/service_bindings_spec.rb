require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::ServiceBindings do
  let(:url) { "http://example.com/v2/service_bindings" }

  describe ".succeed_to_create" do
    subject { CcApiStub::ServiceBindings.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end
end