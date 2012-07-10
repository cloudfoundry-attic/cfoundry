require "cfoundry/baseclient"

module CFoundry
  class UAAClient < BaseClient
    attr_accessor :target, :client_id, :scope, :redirect_uri, :token, :trace

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

    def users
      get("Users", nil => :json)
    end

    private

    def handle_response(response, accept)
      json = accept == :json

      case response.code
      when 200, 204, 302
        if accept == :headers
          return response.headers
        end

        if json
          if response.code == 204
            raise "Expected JSON response, got 204 No Content"
          end

          parse_json(response)
        else
          response
        end

      when 400, 403
        info = parse_json(response)
        raise Denied.new(403, info[:error_description])

      when 401
        info = parse_json(response)
        raise Denied.new(401, info[:error_description])

      when 404
        raise NotFound

      when 409
        info = parse_json(response)
        raise CFoundry::Denied.new(409, info[:message])

      when 411, 500, 504
        begin
          raise_error(parse_json(response))
        rescue JSON::ParserError
          raise BadResponse.new(response.code, response)
        end

      else
        raise BadResponse.new(response.code, response)
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
