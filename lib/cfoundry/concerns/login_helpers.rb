require "base64"

module CFoundry
  module LoginHelpers
    def login_prompts
      @base.uaa.prompts
    end

    def login(credentials)
      token_info = @base.uaa.authorize(credentials)
      @base.token = AuthToken.from_uaa_token_info(token_info)
    end
  end
end
