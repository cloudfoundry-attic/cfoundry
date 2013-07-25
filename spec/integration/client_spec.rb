require "spec_helper"

describe CFoundry::V2::Client do
  before do
    WebMock.allow_net_connect!
  end

  let(:environment_api) { ENV["CF_V2_TEST_TARGET"] || "api.#{a1_domain}"}
  let(:a1_domain) { "a1.cf-app.com" }
  let(:prod_domain) { "run.pivotal.io" }

  describe "setting a new target" do
    it "switches the target cc" do
      client = CFoundry::V2::Client.new("http://api." + a1_domain)
      auth_endpoint = client.info[:authorization_endpoint]
      expect(auth_endpoint).to match a1_domain

      client.target = "http://api." + prod_domain
      auth_endpoint = client.info[:authorization_endpoint]
      expect(auth_endpoint).to match prod_domain
    end

    if ENV["CF_V2_RUN_INTEGRATION"]
      it "requires a re-login" do
        client = CFoundry::V2::Client.new("http://#{environment_api}")
        client.login({username: ENV["CF_V2_TEST_USER"], password: ENV["CF_V2_TEST_PASSWORD"]})
        client.quota_definitions # Getting quota definitions will always be the shortest request that requires auth

        client.target = nil
        client.target = "http://#{environment_api}"
        expect { client.quota_definitions }.to raise_error(CFoundry::InvalidAuthToken)

        client.login({username: ENV["CF_V2_TEST_USER"], password: ENV["CF_V2_TEST_PASSWORD"]})
        client.quota_definitions
      end
    end
  end
end
