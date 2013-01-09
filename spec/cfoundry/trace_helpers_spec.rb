require 'spec_helper'


describe CFoundry::TraceHelpers do

  let(:fake_class) {
    Class.new do
      include CFoundry::TraceHelpers

    end
  }

  let(:request) { Net::HTTP::Get.new("http://api.cloudfoundry.com/foo") }
  let(:response) { Net::HTTPNotFound.new("foo", 404, "bar") }


  shared_examples "request_trace tests" do
    it "traces the provided request" do
      fake_class.new.request_trace(request).should == request_trace
    end

  end

  shared_examples "response_trace tests" do

    before do
      stub(response).body {response_body}
    end

    it "traces the provided response" do
      fake_class.new.response_trace(response).should == response_trace
    end

  end


  describe "#request_trace" do

    context "without a request body" do

      let(:request_trace) { "REQUEST: GET http://api.cloudfoundry.com/foo\nREQUEST_HEADERS:\n  accept : */*" }

      include_examples "request_trace tests"
    end

    context "with a request body" do

      let(:request_trace) { "REQUEST: GET http://api.cloudfoundry.com/foo\nREQUEST_HEADERS:\n  accept : */*\nREQUEST_BODY: Some body text" }

      before do
        request.body= "Some body text"
      end

      include_examples "request_trace tests"
    end

    it "returns nil if request is nil" do
      fake_class.new.request_trace(nil).should == nil
    end
  end


  describe "#response_trace" do

    context "with a non-JSON response body" do

      let(:response_trace) { "RESPONSE: [404]\nRESPONSE_HEADERS:\nSome body" }
      let(:response_body) { "Some body"}

      include_examples "response_trace tests"
    end

    context "with a JSON response body" do

      let(:response_body) { "{\"name\": \"vcap\",\"build\": 2222,\"support\": \"http://support.cloudfoundry.com\"}" }
      let(:response_trace) { "RESPONSE: [404]\nRESPONSE_HEADERS:\n#{MultiJson.dump(MultiJson.load(response_body), :pretty => true)}" }

      include_examples "response_trace tests"
    end

    it "returns nil if response is nil" do
      fake_class.new.response_trace(nil).should == nil
    end
  end
end