require "cfoundry/baseclient"

module CFoundry
  class UAAClient < BaseClient
    attr_accessor :target, :client_id, :scope, :redirect_uri, :trace

    def initialize(
        target = "https://uaa.cloudfoundry.com",
        client_id = "vmc")
      @target = target
      @client_id = client_id
      @scope = ["read"]
      @redirect_uri = "http://uaa.cloudfoundry.com/redirect/vmc"
    end

    def prompts
      get("login", nil => :json)[:prompts]
    end

    def authorize(credentials)
      query = {
        :client_id => @client_id,
        :scope => Array(@scope).join(" "),
        :response_type => "token",
        :redirect_uri => @redirect_uri
      }

      extract_token(
        post(
          { :credentials => credentials },
          "oauth", "authorize",
          :form => :headers,
          :params => query)[:location])
    end

    private

    def extract_token(url)
      _, params = url.split('#')
      return unless params

      values = {}
      params.split("&").each do |pair|
        key, val = pair.split("=")
        values[key] = val
      end

      return unless values["access_token"] && values["token_type"]

      "#{values["token_type"]} #{values["access_token"]}"
    end
  end
end
