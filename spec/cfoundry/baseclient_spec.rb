require 'spec_helper'

describe CFoundry::BaseClient do
  let(:token) { nil }
  let(:base) { CFoundry::BaseClient.new("https://api.cloudfoundry.com", token) }

  describe '#request_uri' do
    let(:url) { base.target + "/foo" }
    let(:method) { Net::HTTP::Get }
    let(:options) { {} }

    def check_request(&block)
      request_stub = stub_request(:get, url).to_return do |req|
        block.call(req)
        {}
      end
      subject
      expect(request_stub).to have_been_requested
    end

    subject { base.request_uri(URI.parse(url), method, options) }

    describe 'headers' do
      %w[Authorization Proxy-User X-Request-Id Content-Type].each do |header_name|
        it "should not include the #{header_name} by default" do
          check_request do |req|
            expect(req.headers).not_to have_key(header_name)
          end
        end
      end

      it "should not provide specific accept mimetypes by default" do
        check_request do |req|
          expect(req.headers["Accept"]).to eql("*/*")
        end
      end

      it 'should always include a content length' do
        check_request do |req|
          expect(req.headers["Content-Length"]).to eql(0)
        end
      end

      context "when a payload is passed" do
        context "when the payload is a string" do
          let(:options) { {:payload => "some payload"} }

          it 'should always include a content length' do
            check_request do |req|
              expect(req.headers["Content-Length"]).to eql("some payload".length)
            end
          end
        end

        context "when the payload is a hash" do
          let(:options) { {:payload => { "key" => "value" }, :content => :json } }

          it 'should always include a content length' do
            check_request do |req|
              expect(req.headers["Content-Length"]).to eql('{"key":"value"}'.length)
            end
          end
        end
      end

      context 'and the token is set' do
        let(:token) { "SomeToken" }

        it 'should include Authorization in the header' do
          check_request do |req|
            expect(req.headers["Authorization"]).to eq token
          end
        end
      end

      context 'and the request_id is set' do
        before { base.request_id = "SomeRequestId" }

        it 'should include X-Request-Id in the header' do
          check_request do |req|
            expect(req.headers["X-Request-Id"]).to eq "SomeRequestId"
          end
        end
      end

      context 'and the proxy is set' do
        before { base.instance_variable_set(:@proxy, "some proxy") }

        it 'should include X-Request-Id in the header' do
          check_request do |req|
            expect(req.headers["Proxy-User"]).to eq "some proxy"
          end
        end
      end

      context 'and the content is passed in' do
        let(:options) { {:content => "text/xml"} }

        it 'should include Content-Type in the header' do
          check_request do |req|
            expect(req.headers["Content-Type"]).to eq "text/xml"
          end
        end
      end

      context 'and custom headers are passed in' do
        let(:options) { {:headers => {"X-Foo" => "Bar"}} }

        it 'should include the custom header in the header' do
          check_request do |req|
            expect(req.headers["X-Foo"]).to eq "Bar"
          end
        end

        context 'and it overrides an existing one' do
          let(:options) { { :content => "text/xml", :headers => { "Content-Type" => "text/html" } } }

          it 'uses the custom header' do
            check_request do |req|
              expect(req.headers["Content-Type"]).to eq "text/html"
            end
          end
        end
      end
    end

    describe 'payload' do

    end

    describe 'errors' do
      context 'when a timeout exception occurs' do
        before { stub_request(:get, url).to_raise(::Timeout::Error) }

        it 'raises the correct error' do
          expect { subject }.to raise_error CFoundry::Timeout, "GET https://api.cloudfoundry.com/foo timed out"
        end
      end

      context 'when an HTTPNotFound error occurs' do
        before { stub_request(:get, url).to_return(:status => 404, :body => "NOT FOUND") }

        it 'raises the correct error' do
          expect {subject}.to raise_error CFoundry::NotFound, "404: NOT FOUND"
        end
      end

      context 'when an HTTPForbidden error occurs' do
        before { stub_request(:get, url).to_return(:status => 403, :body => "NONE SHALL PASS") }

        it 'raises the correct error' do
          expect { subject }.to raise_error CFoundry::Denied, "403: NONE SHALL PASS"
        end
      end

      context "when any other type of error occurs" do
        before { stub_request(:get, url).to_return(:status => 411, :body => "NOT LONG ENOUGH") }

        it 'raises the correct error' do
          expect { subject }.to raise_error CFoundry::BadResponse, "411: NOT LONG ENOUGH"
        end
      end
    end
  end
end
