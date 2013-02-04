module CFoundry
  class AuthToken
    class << self
      def from_uaa_token_info(token_info)
        new(
          token_info.auth_header,
          token_info.info[:refresh_token]
        )
      end

      def from_hash(hash)
        new(
          hash[:token],
          hash[:refresh_token]
        )
      end
    end

    def initialize(auth_header, refresh_token = nil)
      @auth_header = auth_header
      @refresh_token = refresh_token
    end

    attr_reader :auth_header

    def to_hash
      {
        :token => auth_header,
        :refresh_token => @refresh_token
      }
    end

    JSON_HASH = /\{.*?\}/.freeze

    # TODO: rename to #data
    def token_data
      return @token_data if @token_data

      json_hashes = Base64.decode64(@auth_header.split(" ", 2).last)
      data_json = json_hashes.sub(JSON_HASH, "")[JSON_HASH]
      return {} unless data_json

      @token_data = MultiJson.load data_json, :symbolize_keys => true
    rescue MultiJson::DecodeError
      {}
    end
  end
end
