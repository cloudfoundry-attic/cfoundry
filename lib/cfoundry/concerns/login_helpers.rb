require "base64"

module CFoundry
  module LoginHelpers
    def login_prompts
      if @base.uaa
        @base.uaa.prompts
      else
        {
          :username => %w[text Email],
          :password => %w[password Password]
        }
      end
    end

    def login(username, password)
      token_info =
        if @base.uaa
          @base.uaa.authorize(username, password)
        else
          {:access_token => @base.create_token({:password => password}, username)[:token]}
        end

      @base.token = token_info.merge(:access_token_data => token_data(token_info[:access_token]))
    end

    private

    JSON_HASH = /\{.+?\}/.freeze

    def token_data(access_token)
      json_hashes = Base64.decode64(access_token)
      data_json = json_hashes.sub(JSON_HASH, "")[JSON_HASH]
      return {} unless data_json
      MultiJson.load data_json, :symbolize_keys => true
    rescue MultiJson::DecodeError
      {}
    end
  end
end