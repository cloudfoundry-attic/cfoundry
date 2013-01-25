require "spec_helper"

describe CFoundry::AuthToken do
  describe ".from_uaa_token_info" do
    let(:access_token) { Base64.encode64('{"algo": "h1234"}{"user_id": "a6", "email": "a@b.com"}random-bytes') }
    let(:info_hash) do
      {
        :token_type => "bearer",
        :access_token => access_token,
        :refresh_token => "some-refresh-token"
      }
    end


    let(:token_info) { CF::UAA::TokenInfo.new(info_hash) }

    subject { CFoundry::AuthToken.from_uaa_token_info(token_info) }

    describe "#auth_header" do
      its(:auth_header) { should eq "bearer #{access_token}" }
    end

    describe "#to_hash" do
      let(:result_hash) do
        {
          :token => "bearer #{access_token}",
          :refresh_token => "some-refresh-token"
        }
      end

      its(:to_hash) { should eq result_hash }
    end

    describe "#token_data" do
      context "when the access token is encoded as expected" do
        its(:token_data) { should eq({ :user_id => "a6", :email => "a@b.com"}) }
      end

      context "when the access token is not encoded as expected" do
        let(:access_token) { Base64.encode64('random-bytes') }
        its(:token_data) { should eq({}) }
      end

      context "when the access token contains invalid json" do
        let(:access_token) { Base64.encode64('{"algo": "h1234"}{"user_id", "a6", "email": "a@b.com"}random-bytes') }
        its(:token_data) { should eq({}) }
      end
    end
  end

  describe ".from_hash(hash)" do
    let(:hash) do
      {
        :token => "bearer some-bytes",
        :refresh_token => "some-refresh-token"
      }
    end

    subject { CFoundry::AuthToken.from_hash(hash) }

    describe "#auth_header" do
      its(:auth_header) { should eq("bearer some-bytes") }
    end

    describe "#to_hash" do
      its(:to_hash) { should eq(hash) }
    end

    describe "#token_data" do
      its(:token_data) { should eq({}) }
    end
  end
end