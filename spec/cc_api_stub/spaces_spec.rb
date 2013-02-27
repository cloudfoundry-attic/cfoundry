require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Spaces do
  describe ".succeed_to_load" do
    let(:url) { "http://example.com/v2/spaces/234" }
    subject { CcApiStub::Spaces.succeed_to_load }

    it_behaves_like "a stubbed get request"
  end

  describe ".succeed_to_create" do
    let(:url) { "http://example.com/v2/spaces" }
    subject { CcApiStub::Spaces.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end

  describe ".summary_fixture" do
    it "returns a space fixture" do
      CcApiStub::Spaces.summary_fixture.should be_a(Hash)
    end
  end

  describe ".succeed_to_load_summary" do
    let(:url) { "http://example.com/v2/spaces/234/summary" }
    subject { CcApiStub::Spaces.succeed_to_load_summary }

    it_behaves_like "a stubbed get request"

    context "when specifying no_services" do
      subject { CcApiStub::Spaces.succeed_to_load_summary(:no_services => true) }

      it_behaves_like "a stubbed get request", :including_json => {"services" => []}
    end
  end
end