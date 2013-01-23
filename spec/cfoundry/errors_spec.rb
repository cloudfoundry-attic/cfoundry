require 'spec_helper'

describe 'Errors' do
  describe CFoundry::Timeout do
    let(:parent) { Timeout::Error.new }

    subject { CFoundry::Timeout.new("POST", '/blah', parent) }

    its(:to_s) { should eq "POST /blah timed out" }
    its(:method) { should eq "POST" }
    its(:uri) { should eq '/blah' }
    its(:parent) { should eq parent }
  end

  describe CFoundry::APIError do
    let(:request) { { :method => "GET", :url => "http://api.cloudfoundry.com/foo", :headers => {} } }
    let(:response_body) { "NOT FOUND" }
    let(:response) { { :status => 404, :headers => {}, :body => response_body } }

    subject { CFoundry::APIError.new(nil, nil, request, response) }

    its(:to_s) { should eq "404: NOT FOUND" }

    its(:request) { should eq request }

    its(:response) { should eq response }

    describe "#initialize" do

      context "Response body is JSON" do

        let(:response_body) { "{\"description\":\"Something went wrong\"}"}

        it "sets description to description field in parsed JSON" do
          CFoundry::APIError.new(nil, nil, request, response).description.should == "Something went wrong"
        end
      end


      context "Response body is not JSON" do

        let(:response_body) { "Some plain text"}

        it "sets description to body text" do
          CFoundry::APIError.new(nil, nil, request, response).description.should == "Some plain text"
        end
      end

      it "allows override of description" do
        CFoundry::APIError.new("My description", nil, request, response).description.should == "My description"
      end

    end

    describe "#request_trace" do
      its(:request_trace) { should include "REQUEST: " }
    end

    describe "#response_trace" do
      its(:response_trace) { should include "RESPONSE: " }
    end

    it "sets error code to response error code by default" do
      CFoundry::APIError.new(nil, nil, request, response).error_code.should == 404
    end

    it "allows override of error code" do
      CFoundry::APIError.new(nil, 303, request, response).error_code.should == 303
    end

  end
end
