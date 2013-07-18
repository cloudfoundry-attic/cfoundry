require 'spec_helper'

describe CFoundry::BaseClient do
  subject(:client) { CFoundry::BaseClient.new("http://api.example.com") }
  describe "#request" do
    before do
      subject.stub(:handle_response).with(anything, anything, anything)
    end

    context "when given multiple segments" do
      it "encodes the segments and joins them with '/'" do
        subject.should_receive(:request_raw).with("GET", "foo/bar%2Fbaz", {})
        subject.request("GET", "foo", "bar/baz")
      end
    end

    context "when the first segment starts with a '/'" do
      context "and there's only one segment" do
        it "requests with the segment unaltered" do
          subject.should_receive(:request_raw).with("GET", "/v2/apps", {})
          subject.request("GET", "/v2/apps")
        end
      end

      context "and there's more than one segment" do
        it "encodes the segments and joins them with '/'" do
          subject.should_receive(:request_raw).with("GET", "%2Ffoo/bar%2Fbaz", {})
          subject.request("GET", "/foo", "bar/baz")
        end
      end
    end

    context "when there is a token with an auth_header" do
      let(:refresh_token) { nil }
      let(:token) { CFoundry::AuthToken.new("bearer something", refresh_token) }

      before do
        subject.stub(:request_raw)
        subject.token = token
        token.stub(:expires_soon?) { expires_soon? }
      end

      context "and the token is about to expire" do
        let(:uaa) { Object.new }
        let(:expires_soon?) { true }

        context "and there is a refresh token" do
          let(:refresh_token) { "some-refresh-token" }

          it "sets the token's auth header to nil to prevent recursion" do
            subject.stub(:refresh_token!)
            subject.request("GET", "foo")
          end

          it "refreshes the access token" do
            subject.should_receive(:refresh_token!)
            subject.request("GET", "foo")
          end
        end

        context "and there is NOT a refresh token" do
          let(:refresh_token) { nil }

          it "moves along" do
            subject.should_receive(:request_raw).with(anything, anything, anything)
            subject.should_not_receive(:refresh_token!)
            subject.request("GET", "foo")
          end
        end
      end

      context "and the token is NOT about to expire" do
        let(:expires_soon?) { nil }

        it "moves along" do
          subject.should_receive(:request_raw).with(anything, anything, anything)
          subject.should_not_receive(:refresh_token!)
          subject.request("GET", "foo")
        end
      end
    end

    describe "#refresh_token!" do
      let(:uaa) { double }
      let(:access_token) { Base64.encode64(%Q|{"algo": "h1234"}{"a":"b"}random-bytes|) }
      let(:refresh_token) { "xyz" }
      let(:new_access_token) { Base64.encode64(%Q|{"algo": "h1234"}{"a":"x"}random-bytes|) }
      let(:auth_token) { CFoundry::AuthToken.new("bearer #{access_token}", refresh_token) }

      before { subject.stub(:uaa) { uaa } }

      it "refreshes the token with UAA client and assigns it" do
        uaa.should_receive(:try_to_refresh_token!) {
          CFoundry::AuthToken.new("bearer #{new_access_token}", auth_token.refresh_token)
        }

        subject.refresh_token!

        expect(subject.token.auth_header).to eq "bearer #{new_access_token}"
      end
    end

  end

  describe "UAAClient" do
    context "with a valid uaa endpoint" do
      let(:info) { { :authorization_endpoint => "http://uaa.example.com" } }

      before do
        subject.stub(:info) { info }
      end

      describe "#uaa" do
        it "creates a UAAClient on the first call" do
          expect(subject.uaa).to be_a CFoundry::UAAClient
        end

        it "returns the same object on later calls" do
          uaa = subject.uaa
          expect(subject.uaa).to eq uaa
        end

        it "has the same AuthToken as BaseClient" do
          token = CFoundry::AuthToken.new(nil)
          subject.stub(:token) { token }
          expect(subject.uaa.token).to eq token
        end

        context "with the endpoint as 'authorization_endpoint'" do
          let(:info) { { :authorization_endpoint => "foo" } }

          it "uses it to create the UAAClient" do
            expect(subject.uaa).to be_a CFoundry::UAAClient
            expect(subject.uaa.target).to eq "foo"
          end
        end
      end

      describe "#token=" do
        it "propagates the change to #uaa" do
          subject.uaa
          expect(subject.uaa.token).to eq subject.token
          subject.token = CFoundry::AuthToken.new(nil)
          expect(subject.uaa.token).to eq subject.token
        end
      end

      describe "#trace=" do
        it "propagates the change to #uaa" do
          subject.uaa
          subject.trace = true
          expect(subject.uaa.trace).to eq true
          subject.trace = false
          expect(subject.uaa.trace).to eq false
        end
      end
    end

    context "with no uaa endpoint" do
      before do
        subject.stub(:info) { { :something => "else" } }
      end

      describe "#uaa" do
        it "does not return a UAAClient" do
          expect(subject.uaa).to be_nil
        end
      end

    end
  end

  describe "#password_score" do
    context "with a uaa" do
      before do
        subject.stub(:info) { { :authorization_endpoint => "http://uaa.example.com" } }
      end

      it "delegates to the uaa's password strength method" do
        subject.uaa.should_receive(:password_score).with('password')
        subject.password_score('password')
      end
    end

    context "without a uaa" do
      before do
        subject.stub(:info) { { :something => "else" } }
      end

      it "returns :unknown" do
        expect(subject.password_score('password')).to eq(:unknown)
      end
    end
  end

  describe "#stream_url" do
    it "handles a chunked response by yielding chunks as they come in" do
      stub_request(:get, "http://example.com/something").to_return(
        :headers => { "Transfer-Encoding" => "chunked" },
        :body => "result")

      chunks = []
      subject.stream_url("http://example.com/something") do |chunk|
        chunks << chunk
      end

      expect(chunks).to eq(["result"])
    end

    it "handles https" do
      stub_request(:get, "https://example.com/something").to_return(
        :body => "https result")

      chunks = []
      subject.stream_url("https://example.com/something") do |chunk|
        chunks << chunk
      end

      expect(chunks).to eq(["https result"])
    end

    it "raises NotFound if response is 404" do
      stub_request(:get, "http://example.com/something").to_return(
        :status => 404, :body => "result")

      expect {
        subject.stream_url("http://example.com/something")
      }.to raise_error(CFoundry::NotFound, /result/)
    end

    it "raises Denied if response is 403" do
      stub_request(:get, "http://example.com/something").to_return(
        :status => 403, :body => "result")

      expect {
        subject.stream_url("http://example.com/something")
      }.to raise_error(CFoundry::Denied, /result/)
    end

    it "raises Unauthorized if response is 401" do
      stub_request(:get, "http://example.com/something").to_return(
        :status => 401, :body => "result")

      expect {
        subject.stream_url("http://example.com/something")
      }.to raise_error(CFoundry::Unauthorized, /result/)
    end

    it "raises BadRespones if response is unexpected" do
      stub_request(:get, "http://example.com/something").to_return(
        :status => 344, :body => "result")

      expect {
        subject.stream_url("http://example.com/something")
      }.to raise_error(CFoundry::BadResponse, /result/)
    end
  end

  describe "#target=" do
    let(:base_client) { CFoundry::BaseClient.new("https://api.example.com") }
    let(:new_target) { "some-target-url.com"}

    it "sets a new target" do
      expect{base_client.target = new_target}.to change {base_client.target}.from("https://api.example.com").to(new_target)
    end

    it "sets a new target on the rest client" do
      expect{base_client.target = new_target}.to change{base_client.rest_client.target}.from("https://api.example.com").to(new_target)
    end
  end
end
