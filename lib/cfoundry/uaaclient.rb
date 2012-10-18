require "cfoundry/baseclient"

module CFoundry
  class UAAClient < BaseClient
    attr_accessor :target, :client_id, :redirect_uri, :token, :trace

    def initialize(
        target = "https://uaa.cloudfoundry.com",
        client_id = "vmc")
      @target = target
      @client_id = client_id
      @redirect_uri = "https://uaa.cloudfoundry.com/redirect/vmc"
    end

    def prompts
      get("login", nil => :json)[:prompts]
    end

    def authorize(credentials)
      query = {
        :client_id => @client_id,
        :response_type => "token",
        :redirect_uri => @redirect_uri
      }

      extract_token(
        post(
          { :credentials => credentials },
          "oauth", "authorize",
          :form => :headers,
          :params => query)["location"])
    end

    def users
      get("Users", nil => :json)
    end

    def change_password(guid, new, old)
      put(
        { :schemas => ["urn:scim:schemas:core:1.0"],
          :password => new,
          :oldPassword => old
        },
        "User", guid, "password",
        :json => nil)
    end

    private

    def handle_response(response, accept)
      json = accept == :json

      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        if accept == :headers
          return sane_headers(response)
        end

        if json
          if response.is_a?(Net::HTTPNoContent)
            raise "Expected JSON response, got 204 No Content"
          end

          parse_json(response.body)
        else
          response.body
        end

      when Net::BadRequest, Net::HTTPUnauthorized, Net::HTTPForbidden
        info = parse_json(response.body)
        raise Denied.new(response.code, info[:error_description])

      when Net::HTTPNotFound
        raise NotFound

      when Net::HTTPConflict
        info = parse_json(response.body)
        raise CFoundry::Denied.new(response.code, info[:message])

      when Net::HTTPServerError
        begin
          raise_error(parse_json(response.body))
        rescue MultiJson::DecodeError
          raise BadResponse.new(response.code, response.body)
        end

      else
        raise BadResponse.new(response.code, response.body)
      end
    end

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
