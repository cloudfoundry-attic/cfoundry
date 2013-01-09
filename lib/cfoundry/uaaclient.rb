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
      get("login", :accept => :json)[:prompts]
    end

    def authorize(credentials)
      query = {
        :client_id => @client_id,
        :response_type => "token",
        :redirect_uri => @redirect_uri
      }

      auth =
        post(
          { :credentials => credentials },
          "oauth", "authorize",
          :return_response => true,
          :content => :form,
          :accept => :json,
          :params => query)

      if auth.is_a? Net::HTTPRedirection
        extract_token(auth["location"])
      else
        json = parse_json(auth.body)
        raise CFoundry::Denied.new(nil, nil, json[:error_description], auth.code)
      end

    end

    def users
      get("Users", :accept => :json)
    end

    def change_password(guid, new, old)
      put(
        { :password => new, :oldPassword => old },
        "Users", guid, "password",
        :accept => :json,
        :content => :json)
    end

    def password_score(password)
      response = post(
        { :password => password },
        "password", "score",
        :content => :form,
        :accept => :json
      )
      required_score = response[:requiredScore] || 0
      case (response[:score] || 0)
        when 10 then :strong
        when required_score..9 then :good
        else :weak
      end
    end

    private

    def handle_response(response, accept, request)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        accept == :json ? parse_json(response.body) : response.body
      when Net::HTTPBadRequest, Net::HTTPUnauthorized, Net::HTTPForbidden
        info = parse_json(response.body)
        raise Denied.new(request, response, info[:error_description])

      when Net::HTTPNotFound
        raise CFoundry::NotFound.new(request, response)

      when Net::HTTPConflict
        info = parse_json(response.body)
        raise CFoundry::Denied.new(request, response, info[:message])

      else
        raise BadResponse.new(request, response)
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
