module CFoundry
  class AuthToken
    class << self
      def from_uaa_token_info(token_info)
        new(
          token_info.auth_header,
          token_info.info[:refresh_token],
          get_token_data(token_info)
        )
      end

      def from_cc_token(token_string)
        new(token_string)
      end

      def from_hash(hash)
        new(hash[:token], hash[:refresh_token])
      end

      private

      JSON_HASH = /\{.+?\}/.freeze

      def get_token_data(token_info)
        json_hashes = Base64.decode64(token_info.info[:access_token])
        data_json = json_hashes.sub(JSON_HASH, "")[JSON_HASH]
        return {} unless data_json
        MultiJson.load data_json, :symbolize_keys => true
      rescue MultiJson::DecodeError
        {}
      end
    end

    def initialize(auth_header, refresh_token = nil, token_data = nil)
      @auth_header = auth_header
      @refresh_token = refresh_token
      @token_data = token_data
    end

    attr_reader :auth_header

    def to_hash
      {
        :token => auth_header,
        :refresh_token => @refresh_token
      }
    end

    def token_data
      @token_data || {}
    end
  end
end