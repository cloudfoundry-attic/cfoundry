require "json"
require "base64"

require "cfoundry/baseclient"
require "cfoundry/uaaclient"

require "cfoundry/errors"

module CFoundry::V2
  class Base < CFoundry::BaseClient
    attr_accessor :target, :token, :proxy, :trace

    def initialize(
        target = "https://api.cloudfoundry.com",
        token = nil)
      @target = target
      @token = token
    end


    # invalidate token data when changing token
    def token=(t)
      @token = t
    end


    # The UAA used for this client.
    #
    # `false` if no UAA (legacy)
    def uaa
      return @uaa unless @uaa.nil?

      endpoint = info[:authorization_endpoint]
      return @uaa = false unless endpoint

      @uaa = CFoundry::UAAClient.new(endpoint)
      @uaa.trace = @trace
      @uaa.token = @token
      @uaa
    end


    # Cloud metadata
    def info
      get("info", nil => :json)
    end


    [ :app, :organization, :app_space, :user, :runtime, :framework,
      :service, :service_plan, :service_binding, :service_instance
    ].each do |obj|
      plural = "#{obj}s"

      define_method(obj) do |guid, *args|
        depth, _ = args
        depth ||= 1

        params = { :"inline-relations-depth" => depth }

        get("v2", plural, guid, nil => :json, :params => params)
      end

      define_method(:"create_#{obj}") do |payload|
        post(payload, "v2", plural, :json => :json)
      end

      define_method(:"delete_#{obj}") do |guid|
        delete("v2", plural, guid, nil => nil)
        true
      end

      define_method(:"update_#{obj}") do |guid, payload|
        put(payload, "v2", plural, guid, :json => :json)
      end

      define_method(plural) do |*args|
        depth, query = args
        depth ||= 1

        params = { :"inline-relations-depth" => depth }

        if query
          params[:q] = "#{query.keys.first}:#{query.values.first}"
        end

        get("v2", plural, nil => :json, :params => params)
      end
    end

    alias :spaces :app_spaces
    alias :space :app_space
    alias :update_space :update_app_space
    alias :delete_space :delete_app_space
    alias :create_space :create_app_space

    private

    def handle_response(response, accept)
      json = accept == :json

      case response.code
      when 200, 201, 204, 302
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

      when 400
        info = parse_json(response)
        raise CFoundry::APIError.new(info[:code], info[:description])

      when 401, 403
        info = parse_json(response)
        raise CFoundry::Denied.new(info[:code], info[:description])

      when 404
        raise CFoundry::NotFound

      when 411, 500, 504
        begin
          info = parse_json(response)
          raise CFoundry::APIError.new(info[:code], info[:description])
        rescue JSON::ParserError
          raise CFoundry::BadResponse.new(response.code, response)
        end

      else
        raise CFoundry::BadResponse.new(response.code, response)
      end
    end
  end
end
