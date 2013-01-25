require "base64"

module CFoundry
  module LoginHelpers
    def login_prompts
      @base.uaa.prompts
    end

    def login(username, password)
      @base.token = AuthToken.from_uaa_token_info(@base.uaa.authorize(username, password))
    end
  end
end