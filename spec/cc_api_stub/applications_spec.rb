require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Applications do
  describe ".succeed_to_load" do
    let(:url) { "http://example.com/v2/apps/234" }
    subject { CcApiStub::Applications.succeed_to_load }

    it_behaves_like "a stubbed get request"
  end

  describe ".succeed_to_create" do
    let(:url) { "http://example.com/v2/apps" }
    subject { CcApiStub::Applications.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end

  describe ".succeed_to_update" do
    let(:url) { "http://example.com/v2/apps/234" }
    subject { CcApiStub::Applications.succeed_to_update }

    it_behaves_like "a stubbed put request"
  end

  describe ".succeed_to_map_route" do
    let(:url) { "http://example.com/v2/apps/234/routes/123" }
    subject { CcApiStub::Applications.succeed_to_map_route }

    it_behaves_like "a stubbed put request", :code => 201
  end

  describe ".succeed_to_load_stats" do
    let(:url) { "http://example.com/v2/apps/234/stats" }
    subject { CcApiStub::Applications.succeed_to_load_stats }

    it_behaves_like "a stubbed get request"
  end
  
  describe ".summary_fixture" do
    it "loads a fixture file" do
      CcApiStub::Applications.summary_fixture.should be_a(Hash)
    end
  end

  describe "succeed_to_load_summary" do
    let(:url) { "http://example.com/v2/apps/234/summary" }

    context "with default args" do
      subject { CcApiStub::Applications.succeed_to_load_summary }

      it_behaves_like "a stubbed get request", :including_json => { "state" => "STARTED" }
    end

    context "with user set args" do
      subject { CcApiStub::Applications.succeed_to_load_summary(:state => "FLAPPING") }

      it_behaves_like "a stubbed get request", :including_json => { "state" => "FLAPPING" }
    end
  end

  describe ".succeed_to_load_service_bindings" do
    let(:url) { "http://example.com/v2/apps/234/service_bindings" }
    subject { CcApiStub::Applications.succeed_to_load_service_bindings }

    it_behaves_like "a stubbed get request"
  end
end