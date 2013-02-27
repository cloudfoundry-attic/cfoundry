require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Services do
  describe ".succeed_to_load" do
    let(:url) { "http://example.com/v2/services?inline-relations-depth=1" }
    subject { CcApiStub::Services.succeed_to_load }

    it_behaves_like "a stubbed get request"
  end
end