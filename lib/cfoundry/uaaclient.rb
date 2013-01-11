require "cfoundry/baseclient"
require 'uaa'

module CFoundry
  class UAAClient < BaseClient
    attr_accessor :target, :client_id, :token, :trace

    def initialize(
      target = "https://uaa.cloudfoundry.com",
        client_id = "vmc")
      @target = target
      @client_id = client_id
      @token_issuer = CF::UAA::TokenIssuer.new(
        target, client_id, :symbolize_keys => true)
      CF::UAA::Misc.symbolize_keys = true
    end

    def prompts
      CF::UAA::Misc.server(target)[:prompts]
    end

    def authorize(credentials)
      @token_issuer.implicit_grant_with_creds(credentials).auth_header
    rescue CF::UAA::BadResponse => e
      status_code = e.message[/\d+/] || 400
      raise CFoundry::Denied.new(nil, nil, "Authorization failed", status_code)
    end

    def users
      CF::UAA::Scim.new(target, token).query(:user)
    end

    def change_password(guid, new, old)
      CF::UAA::Scim.new(target, token).change_password(guid, new, old)
    end

    def password_score(password)
      response = CF::UAA::Misc.password_strength(target, password)

      required_score = response[:requiredScore] || 0
      case (response[:score] || 0)
        when 10 then
          :strong
        when required_score..9 then
          :good
        else
          :weak
      end
    end
  end
end
