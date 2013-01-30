require 'spec_helper'

describe CFoundry::BaseClient do
  subject { CFoundry::BaseClient.new }

  describe "#request" do
    before do
      stub(subject).handle_response(anything, anything, anything)
    end

    context "when given multiple segments" do
      it "encodes the segments and joins them with '/'" do
        mock(subject).request_raw("GET", "foo/bar%2Fbaz", {})
        subject.request("GET", "foo", "bar/baz")
      end
    end

    context "when the first segment starts with a '/'" do
      context "and there's only one segment" do
        it "requests with the segment unaltered" do
          mock(subject).request_raw("GET", "/v2/apps", {})
          subject.request("GET", "/v2/apps")
        end
      end

      context "and there's more than one segment" do
        it "encodes the segments and joins them with '/'" do
          mock(subject).request_raw("GET", "%2Ffoo/bar%2Fbaz", {})
          subject.request("GET", "/foo", "bar/baz")
        end
      end
    end
  end

  describe "UAAClient" do
    before do
      stub(subject).info { { :authorization_endpoint => "http://uaa.example.com" } }
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
        stub(subject).token { token }
        expect(subject.uaa.token).to eq token
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
end
