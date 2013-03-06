require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Login do
  describe '.succeeds_to_find_uaa' do
    let(:host) { 'http://example.com:8181' }
    let(:url) { host + "/info" }
    subject { CcApiStub::Login.succeeds_to_find_uaa(host) }

    it_behaves_like "a stubbed get request", :including_json => {'token_endpoint' => 'https://uaa.localhost'}
  end

  describe '.succeeds_to_login_as_admin' do
    let(:url) { "http://uaa.localhost/oauth/authorize" }
    subject { CcApiStub::Login::succeeds_to_login_as_admin }

    it_behaves_like "a stubbed post request", :code => 302, :ignore_response => true
  end
end
