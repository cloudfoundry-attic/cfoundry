require 'spec_helper'

describe CFoundry::RestClient do
  let(:token) { nil }
  let(:rest_client) { CFoundry::RestClient.new("https://api.cloudfoundry.com", token) }

  describe '#request' do
    let(:path) { "some-path" }
    let(:url) { "https://api.cloudfoundry.com/some-path" }
    let(:method) { "GET" }
    let(:options) { {} }

    def check_request(method = :get, &block)
      request_stub = stub_request(method, url).to_return do |req|
        block.call(req)
        {}
      end
      subject
      expect(request_stub).to have_been_requested
    end

    subject { rest_client.request(method, path, options) }

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
          let(:options) { { :payload => "some payload"} }

          it 'includes a content length matching the payload size' do
            check_request do |req|
              expect(req.headers["Content-Length"]).to eql("some payload".length)
            end
          end
        end

        context "when the payload is a hash and the content-type is JSON" do
          let(:options) { { :payload => { "key" => "value" }, :content => :json } }

          it 'includes a content length matching the JSON encoded length' do
            check_request do |req|
              expect(req.headers["Content-Length"]).to eql('{"key":"value"}'.length)
            end
          end
        end

        context "when the payload is a hash (i.e. multipart upload)" do
          let(:method) { "PUT" }
          let(:options) { { :payload => { "key" => "value" } } }

          it 'includes a nonzero content length' do
            check_request(:put) do |req|
              expect(req.headers["Content-Length"].to_i).to be > 0
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
        before { rest_client.request_id = "SomeRequestId" }

        it 'should include X-Request-Id in the header' do
          check_request do |req|
            expect(req.headers["X-Request-Id"]).to eq "SomeRequestId"
          end
        end
      end

      context 'and the proxy is set' do
        before { rest_client.instance_variable_set(:@proxy, "some proxy") }

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
    end

    describe "the return value" do
      before do
        stub_request(:get, url).to_return({
          :status => 201,
          :headers => { "Content-Type" => "application/json"},
          :body => '{ "foo": 1 }'
        })
      end

      it "returns a request hash and a response hash" do
        expect(subject).to be_an(Array)
        expect(subject.length).to eq(2)
      end

      describe "the returned request hash" do
        it "returns a hash of :headers, :url, :body and :method" do
          expect(subject[0]).to eq({
            :url => url,
            :method => "GET",
            :headers => { "Content-Length" => 0 },
            :body => nil
          })
        end
      end

      describe "the returned response hash" do
        it "returns a hash of :headers, :status, :body" do
          expect(subject[1]).to eq({
            :status => "201",
            :headers => { "content-type" => "application/json"},
            :body => '{ "foo": 1 }'
          })
        end
      end
    end

    describe 'trace' do
      before do
        rest_client.trace = true
        stub_request(:get, url).to_return(:status => 200, :headers => { "content-type" => "application/json" }, :body => '{"some": "json"}')
      end

      it "prints the request and the response" do
        mock(rest_client).print_request({:headers=>{"Content-Length"=>0}, :url=>"https://api.cloudfoundry.com/some-path", :method=>"GET", :body=>nil})
        mock(rest_client).print_response({ :status => "200", :headers => { "content-type" => "application/json" }, :body => '{"some": "json"}' })
        subject
      end
    end
  end
end
