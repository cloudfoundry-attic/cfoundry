require 'spec_helper'

describe CFoundry::BaseClient do
  describe "#request" do
    subject { CFoundry::BaseClient.new }

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
end
