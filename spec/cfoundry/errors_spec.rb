require 'spec_helper'

describe 'Errors' do
  describe CFoundry::Timeout do
    let(:parent) { Timeout::Error.new }

    subject { CFoundry::Timeout.new(Net::HTTP::Post, '/blah', parent) }

    its(:to_s) { should eq "POST /blah timed out" }
    its(:method) { should eq Net::HTTP::Post }
    its(:uri) { should eq '/blah' }
    its(:parent) { should eq parent }
  end

  describe CFoundry::APIError do
    let(:request) { Net::HTTP::Get.new("http://api.cloudfoundry.com/foo") }
    let(:response) { Net::HTTPNotFound.new("foo", 404, "bar")}
    let(:response_body) { "NOT FOUND" }
    subject { CFoundry::APIError.new(request, response) }

    before do
      stub(response).body {response_body}
    end

    its(:to_s) { should eq "404: NOT FOUND" }

    its(:request) { should eq request }

    its(:response) { should eq response }

    describe "#initialize" do

      context "Response body is JSON" do

        let(:response_body) { "{\"description\":\"Something went wrong\"}"}

        it "sets description to description field in parsed JSON" do
          CFoundry::APIError.new(request, response).description.should == "Something went wrong"
        end
      end


      context "Response body is not JSON" do

        let(:response_body) { "Some plain text"}

        it "sets description to body text" do
          CFoundry::APIError.new(request, response).description.should == "Some plain text"
        end
      end

      it "allows override of description" do
        CFoundry::APIError.new(request, response, "My description").description.should == "My description"
      end

    end

    it "sets error code to response error code by default" do
      CFoundry::APIError.new(request, response).error_code.should == 404
    end

    it "allows override of error code" do
      CFoundry::APIError.new(request, response, nil, 303).error_code.should == 303
    end

  end
end
