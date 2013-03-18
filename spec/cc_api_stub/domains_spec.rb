require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Domains do
  describe ".succeed_to_create" do
    let(:url) { "http://example.com/v2/domains/" }
    subject { CcApiStub::Domains.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end

  describe ".succeed_to_delete" do
    let(:url) { "http://example.com/v2/domains/1234" }
    subject { CcApiStub::Domains.succeed_to_delete }

    it_behaves_like "a stubbed delete request"
  end

  describe ".succeed_to_load_spaces" do
    let(:url) { "http://example.com/v2/domains/domain-id-1/spaces?inline-relationship-depth=1" }
    subject { CcApiStub::Domains.succeed_to_load_spaces }

    it_behaves_like "a stubbed get request"
  end
end