require "spec_helper"

describe CFoundry::TraceHelpers do
  let(:tracehelper_test_class) { Class.new { include CFoundry::TraceHelpers } }
  let(:request) do
    {
      :method => "GET",
      :url => "http://api.cloudfoundry.com/foo",
      :headers => { "bb-foo" => "bar", "accept" => "*/*" }
    }
  end
  let(:response) { { :status => 404, :body => "not found", :headers => {} } }

  shared_examples "request_trace tests" do
    it { should include request_trace }
    it { should include header_trace }
    it { should include body_trace }
  end

  shared_examples "response_trace tests" do
    before { response[:body] = response_body }

    it "traces the provided response" do
      tracehelper_test_class.new.response_trace(response).should == response_trace
    end
  end

  describe "#request_trace" do
    let(:request_trace) { "REQUEST: GET http://api.cloudfoundry.com/foo" }
    let(:header_trace) { "REQUEST_HEADERS:\n  accept : */*\n  bb-foo : bar" }
    let(:body_trace) { "" }

    subject { tracehelper_test_class.new.request_trace(request) }

    context "without a request body" do
      include_examples "request_trace tests"
    end

    context "with a request body" do
      let(:body_trace) { "REQUEST_BODY: Some body text" }

      before { request[:body] = "Some body text" }

      include_examples "request_trace tests"
    end

    it "returns nil if request is nil" do
      tracehelper_test_class.new.request_trace(nil).should == nil
    end

    context "with protected attributes" do
      let(:header_trace) { "REQUEST_HEADERS:\n  Authorization : [PRIVATE DATA HIDDEN]" }
      let(:request) do
        {
            :method => "GET",
            :url => "http://api.cloudfoundry.com/foo",
            :headers => { 'Authorization' => "SECRET STUFF" }
        }
      end
      include_examples "request_trace tests"
    end
  end


  describe "#response_trace" do
    context "with a non-JSON response body" do
      let(:response_trace) { "RESPONSE: [404]\nRESPONSE_HEADERS:\n\nRESPONSE_BODY:\nSome body" }
      let(:response_body) { "Some body"}

      include_examples "response_trace tests"
    end

    context "with a JSON response body" do
      let(:response_body) { "{\"name\": \"vcap\",\"build\": 2222,\"support\": \"http://support.cloudfoundry.com\"}" }
      let(:response_trace) { "RESPONSE: [404]\nRESPONSE_HEADERS:\n\nRESPONSE_BODY:\n#{MultiJson.dump(MultiJson.load(response_body), :pretty => true)}" }

      include_examples "response_trace tests"
    end

    it "returns nil if response is nil" do
      tracehelper_test_class.new.response_trace(nil).should == nil
    end
  end
end