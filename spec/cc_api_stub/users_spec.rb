require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Users do
  describe ".succeed_to_load" do
    let(:url) { "http://example.com/v2/users/2345?inline-relations-depth=2" }
    let(:options) { {} }
    subject { CcApiStub::Users.succeed_to_load(options) }

    it_behaves_like "a stubbed get request"

    context "when setting a user id" do
      let(:options) { { :id => "some-id" } }

      it_behaves_like "a stubbed get request", :including_json => { "metadata" => { "guid" => "some-id" } }
    end

    context "when setting an organization_id" do
      let(:options) { { :organization_id => "some-id" } }

      it_behaves_like "a stubbed get request", :including_json => Proc.new { |json|
        json["entity"]["organizations"][0]["metadata"]["guid"].should == "some-id"
      }
    end

    context "when specifying no_spaces" do
      let(:options) { { :no_spaces => true } }

      it_behaves_like "a stubbed get request", :including_json => Proc.new { |json|
        json["entity"]["organizations"][0]["entity"]["spaces"].should == []
      }
    end

    context "when specifying custom permissions" do
      let(:options) { { :permissions => [:space_manager, :space2_auditor] } }

      it_behaves_like "a stubbed get request", :including_json => {
        "entity" =>
          {
            "managed_spaces" => [{"metadata" => { "guid" => "space-id-1" }, "entity" => {}}],
            "audited_spaces" => [{"metadata" => { "guid" => "space-id-2" }, "entity" => {}}]
          }
      }
    end
  end

  describe ".fail_to_find" do
    let(:url) { "http://example.com/v2/users/2345" }
    subject { CcApiStub::Users.fail_to_find }

    it_behaves_like "a stubbed get request", :code => 404
  end

  describe ".succeed_to_create" do
    let(:url) { "http://example.com/v2/users" }
    subject { CcApiStub::Users.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end

  describe ".fail_to_create" do
    let(:url) { "http://example.com/v2/users" }
    subject { CcApiStub::Users.fail_to_create }

    it_behaves_like "a stubbed post request", :code => 500
  end

  describe ".succeed_to_replace_permissions" do
    let(:url) { "http://example.com/v2/users/123" }
    subject { CcApiStub::Users.succeed_to_replace_permissions }

    it_behaves_like "a stubbed put request", :ignore_response => true
  end

  describe ".fail_to_replace_permissions" do
    let(:url) { "http://example.com/v2/users/123" }
    subject { CcApiStub::Users.fail_to_replace_permissions }

    it_behaves_like "a stubbed put request", :ignore_response => true, :code => 500
  end

  describe ".organizations_fixture" do
    subject { CcApiStub::Users.organizations_fixture }

    it "returns a fixture" do
      subject.should be_a Array
    end
  end

  describe ".organizations_fixture_hash" do
    subject { CcApiStub::Users.organization_fixture_hash }

    it "returns a fixture" do
      subject.should be_a Hash
    end

    context "when specifying options" do
      subject { CcApiStub::Users.organization_fixture_hash(:no_spaces => true, :no_managers => true) }

      it "takes options into account" do
        subject[:entity][:spaces].should be_nil
        subject[:entity][:managers].should be_nil
      end
    end
  end
end
