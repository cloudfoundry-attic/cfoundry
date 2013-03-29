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

    shared_examples "handling responses" do |verb|
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

        context 'when an HTTPUnauthorized error occurs' do
          before { stub_request(:any, url).to_return(:status => 401, :body => "YE FOO SHALL BAR") }

          it 'raises the correct error' do
            expect { subject }.to raise_error CFoundry::Unauthorized, "401: YE FOO SHALL BAR"
          end
        end

        context "when any other type of error occurs" do
          before { stub_request(:any, url).to_return(:status => 411, :body => "NOT LONG ENOUGH") }

          it 'raises the correct error' do
            expect { subject }.to raise_error CFoundry::BadResponse, "411: NOT LONG ENOUGH"
          end
        end

        it 'includes the request and response hashes when it raises errors' do
          stub_request(:any, url).to_return(:status => 411, :body => "NOT LONG ENOUGH")

          begin
            subject
          rescue CFoundry::BadResponse => e
            expect(e.response).to eq({
              :status => "411",
              :headers => {},
              :body => "NOT LONG ENOUGH"
            })
            expect(e.request).to eq({
              :headers => { "Content-Length" => 0 },
              :method => verb,
              :body => nil,
              :url => "https://api.cloudfoundry.com/some-path"
            })
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
            mock(rest_client).request(verb, "first-segment/next-segment", {}) { [request, response] }
            subject
          end
        end

        context "when an options has is supplied" do
          let(:args) { segments + [options] }

          it "makes a request with the correct url and options" do
            mock(rest_client).request(verb, "first-segment/next-segment", options) { [request, response] }
            subject
          end
        end
      end

      context "when a single path segment is passed" do
        context "when an options hash is not supplied" do
          let(:args) { ["first-segment"] }

          it "makes a request with the correct url and options" do
            mock(rest_client).request(verb, "first-segment", {}) { [request, response] }
            subject
          end
        end

        context "when an options has is supplied" do
          let(:args) { ["first-segment", options] }

          it "makes a request with the correct url and options" do
            mock(rest_client).request(verb, "first-segment", options) { [request, response] }
            subject
          end
        end
      end
    end

    let(:response) { { :status => "201", :headers => { "some-header-key" => "some-header-value" }, :body => "some-body" } }
    let(:request) do
      {
        :method => "GET",
        :url => "http://api.cloudfoundry.com/some-path",
        :headers => { "some-header-key" => "some-header-value" },
        :body => "some-body"
      }
    end

    describe "#get" do
      subject { base.get(*args) }

      it "makes a GET request" do
        mock(rest_client).request("GET", "some-path", options) { [request, response] }
        subject
      end

      include_examples "handling responses", "GET"
      include_examples "normalizing arguments", "GET"
    end

    describe "#post" do
      subject { base.post(*args) }

      it "makes a POST request" do
        mock(rest_client).request("POST", "some-path", options) { [request, response] }
        subject
      end

      include_examples "handling responses", "POST"
      include_examples "normalizing arguments", "POST"
    end

    describe "#put" do
      subject { base.put(*args) }

      it "makes a PUT request" do
        mock(rest_client).request("PUT", "some-path", options) { [request, response] }
        subject
      end

      include_examples "handling responses", "PUT"
      include_examples "normalizing arguments", "PUT"
    end

    describe "#delete" do
      subject { base.delete(*args) }

      it "makes a DELETE request" do
        mock(rest_client).request("DELETE", "some-path", options) { [request, response] }
        subject
      end

      include_examples "handling responses", "DELETE"
      include_examples "normalizing arguments", "DELETE"
    end
  end

  describe "#resource_match" do
    let(:fingerprints) { "some-fingerprints" }

    it "makes a PUT request to the resource_match endpoint with the correct payload" do
      stub = stub_request(:put, "https://api.cloudfoundry.com/v2/resource_match").
        with(:body => fingerprints).
        to_return(:body => "{}")
      base.resource_match(fingerprints)
      expect(stub).to have_been_requested
    end
  end

  describe "#upload_app" do
    let(:guid) { "some-guid" }
    let(:bits) { "some-bits" }
    let(:fake_zipfile) { File.new("#{SPEC_ROOT}/fixtures/empty_file") }

    it "makes a PUT request to the app bits endpoint with the correct payload" do
      stub = stub_request(:put, "https://api.cloudfoundry.com/v2/apps/#{guid}/bits").to_return(:body => "{}")
      base.upload_app(guid, fake_zipfile)
      expect(stub).to have_been_requested
    end

    context "when there is no file to upload" do
      it "does not include 'application' in the request hash" do
        stub =
          stub_request(
            :put,
            "https://api.cloudfoundry.com/v2/apps/#{guid}/bits"
          ).with { |request|
            request.body =~ /name="resources"/ &&
              request.body !~ /name="application"/
          }.to_return(
            :body => "{}"
          )
        base.upload_app(guid)
        expect(stub).to have_been_requested
      end
    end
  end

  describe "#stream_file" do
    let(:app_guid) { "1234" }
    let(:instance_guid) { "3456" }
    let(:api_url) { "https://api.cloudfoundry.com/v2/apps/#{app_guid}/instances/#{instance_guid}/files/some/path/segments" }
    let(:file_url) { "http://api.cloudfoundry.com/static/path/to/some/file" }

    before do
      stub(base).token { CFoundry::AuthToken.new("bearer foo") }
    end

    it "follows the redirect returned by the files endpoint" do
      stub_request(:get, api_url).to_return(
        :status => 301,
        :headers => { "location" => file_url },
        :body =>  ""
      )

      request =
        stub_request(
          :get, file_url + "&tail"
        ).with(
          :headers => { "Accept" => "*/*", "Authorization" => "bearer foo" }
        ).to_return(
          :status => 200,
          :body => "some body chunks"
        )

      base.stream_file(app_guid, instance_guid, "some", "path", "segments") do |body|
        expect(request).to have_been_made
        expect(body).to eql("some body chunks")
      end
    end
  end
end
