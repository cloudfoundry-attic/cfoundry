require "base64"
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

      context "when the auth header is nil" do
        before do
          subject.auth_header = nil
        end

        its(:token_data) { should eq({}) }
      end
    end
  end

  describe ".from_hash(hash)" do
    let(:token_data) { '{"baz":"buzz"}' }
    let(:token) { Base64.encode64("{\"foo\":1}#{token_data}") }

    let(:hash) do
      {
        :token => "bearer #{token}",
        :refresh_token => "some-refresh-token"
      }
    end

    subject { CFoundry::AuthToken.from_hash(hash) }

    describe "#auth_header" do
      its(:auth_header) { should eq("bearer #{token}") }
    end

    describe "#to_hash" do
      its(:to_hash) { should eq(hash) }
    end

    describe "#token_data" do
      its(:token_data) { should eq({ :baz => "buzz" }) }
    end
  end

  describe "#auth_header=" do
    let(:access_token) { Base64.encode64('{"algo": "h1234"}{"user_id": "a6", "email": "a@b.com"}random-bytes') }
    let(:other_access_token) { Base64.encode64('{"algo": "h1234"}{"user_id": "b6", "email": "a@b.com"}random-bytes') }

    subject { CFoundry::AuthToken.new("bearer #{access_token}") }

    it "invalidates @token_data" do
      subject.token_data
      expect {
        subject.auth_header = "bearer #{other_access_token}"
      }.to change { subject.token_data[:user_id] }.from("a6").to("b6")
    end
  end

  describe "#expires_soon?" do
    let(:access_token) { Base64.encode64(%Q|{"algo": "h1234"}{"exp":#{expiration.to_i}}random-bytes|) }

    subject { CFoundry::AuthToken.new("bearer #{access_token}") }

    context "when the token expires in less than 1 minute" do
      let(:expiration) { Time.now + 59 }

      it "returns true" do
        Timecop.freeze do
          expect(subject.expires_soon?).to be_true
        end
      end
    end

    context "when the token expires in greater than or equal to 1 minute" do
      let(:expiration) { Time.now + 60 }

      it "returns false" do
        Timecop.freeze do
          expect(subject.expires_soon?).to be_false
        end
      end
    end
  end
end
