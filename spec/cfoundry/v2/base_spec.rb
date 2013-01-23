require "spec_helper"

describe CFoundry::V2::Base do
  let(:target) { "https://api.cloudfoundry.com" }
  let(:base) { CFoundry::V2::Base.new(target) }

  describe "helper methods for HTTP verbs" do
    let(:rest_client) { base.rest_client }
    let(:path) { "some-path" }
    let(:options) { { :some => :option} }
    let(:url) { target + "/" + path }
    let(:args) { [path, options] }

    shared_examples "handling responses" do
      context 'when successful' do
        context 'and the accept type is JSON' do
          let(:options) { {:accept => :json} }

          it 'returns the parsed JSON' do
            stub_request(:any, 'https://api.cloudfoundry.com/some-path').to_return(:status => 200, :body => "{\"hello\": \"there\"}")
            expect(subject).to eq(:hello => "there")
          end
        end

        context 'and the accept type is not JSON' do
          let(:options) { {:accept => :form} }

          it 'returns the body' do
            stub_request(:any, 'https://api.cloudfoundry.com/some-path').to_return :status => 200, :body =>  "body"
            expect(subject).to eq "body"
          end
        end
      end

      context 'when an error occurs' do
        let(:response_code) { 404 }

        it 'raises the correct error if JSON is parsed successfully' do
          stub_request(:any, 'https://api.cloudfoundry.com/some-path').to_return(
            :status => response_code,
            :body =>  "{\"code\": 111, \"description\": \"Something bad happened\"}"
          )
          expect {subject}.to raise_error(CFoundry::SystemError, "111: Something bad happened")
        end

        it 'raises the correct error if code is missing from response' do
          stub_request(:any, 'https://api.cloudfoundry.com/some-path').to_return(
            :status => response_code,
            :body =>  "{\"description\": \"Something bad happened\"}"
          )
          expect {subject}.to raise_error CFoundry::NotFound
        end

        it 'raises the correct error if response body is not JSON' do
          stub_request(:any, 'https://api.cloudfoundry.com/some-path').to_return(
            :status => response_code,
            :body =>  "Error happened"
          )
          expect {subject}.to raise_error CFoundry::NotFound
        end

        it 'raises a generic APIError if code is not recognized' do
          stub_request(:any, 'https://api.cloudfoundry.com/some-path').to_return :status => response_code,
            :body =>  "{\"code\": 6932, \"description\": \"Something bad happened\"}"
          expect {subject}.to raise_error CFoundry::APIError, "6932: Something bad happened"
        end

        context 'when a timeout exception occurs' do
          before { stub_request(:any, url).to_raise(::Timeout::Error) }

          it 'raises the correct error' do
            expect { subject }.to raise_error CFoundry::Timeout, /#{url} timed out/
          end
        end

        context 'when an HTTPNotFound error occurs' do
          before { stub_request(:any, url).to_return(:status => 404, :body => "NOT FOUND") }

          it 'raises the correct error' do
            expect {subject}.to raise_error CFoundry::NotFound, "404: NOT FOUND"
          end
        end

        context 'when an HTTPForbidden error occurs' do
          before { stub_request(:any, url).to_return(:status => 403, :body => "NONE SHALL PASS") }

          it 'raises the correct error' do
            expect { subject }.to raise_error CFoundry::Denied, "403: NONE SHALL PASS"
          end
        end

        context "when any other type of error occurs" do
          before { stub_request(:any, url).to_return(:status => 411, :body => "NOT LONG ENOUGH") }

          it 'raises the correct error' do
            expect { subject }.to raise_error CFoundry::BadResponse, "411: NOT LONG ENOUGH"
          end
        end
      end
    end

    shared_examples "normalizing arguments" do |verb|
      context "when multiple path segments are passed" do
        let(:segments) { ["first-segment", "next-segment"] }

        context "when an options hash is not supplied" do
          let(:args) { segments }

          it "makes a request with the correct url and options" do
            mock(rest_client).request(verb, "/first-segment/next-segment", {}) { response }
            subject
          end
        end

        context "when an options has is supplied" do
          let(:args) { segments + [options] }

          it "makes a request with the correct url and options" do
            mock(rest_client).request(verb, "/first-segment/next-segment", options) { response }
            subject
          end
        end
      end

      context "when a single path segment is passed" do
        context "when an options hash is not supplied" do
          let(:args) { ["first-segment"] }

          it "makes a request with the correct url and options" do
            mock(rest_client).request(verb, "/first-segment", {}) { response }
            subject
          end
        end

        context "when an options has is supplied" do
          let(:args) { ["first-segment", options] }

          it "makes a request with the correct url and options" do
            mock(rest_client).request(verb, "/first-segment", options) { response }
            subject
          end
        end
      end
    end

    let(:response) { { :status => "201", :headers => { "some-header-key" => "some-header-value" }, :body => "some-body" } }

    describe "#get" do
      subject { base.get(*args) }

      it "makes a GET request" do
        mock(rest_client).request("GET", "/some-path", options) { response }
        subject
      end

      include_examples "handling responses"
      include_examples "normalizing arguments", "GET"
    end

    describe "#post" do
      subject { base.post(*args) }

      it "makes a POST request" do
        mock(rest_client).request("POST", "/some-path", options) { response }
        subject
      end

      include_examples "handling responses"
      include_examples "normalizing arguments", "POST"
    end

    describe "#put" do
      subject { base.put(*args) }

      it "makes a PUT request" do
        mock(rest_client).request("PUT", "/some-path", options) { response }
        subject
      end

      include_examples "handling responses"
      include_examples "normalizing arguments", "PUT"
    end

    describe "#delete" do
      subject { base.delete(*args) }

      it "makes a DELETE request" do
        mock(rest_client).request("DELETE", "/some-path", options) { response }
        subject
      end

      include_examples "handling responses"
      include_examples "normalizing arguments", "DELETE"
    end
  end
end
