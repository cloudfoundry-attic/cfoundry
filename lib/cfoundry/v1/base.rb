require "multi_json"

require "cfoundry/baseclient"
require "cfoundry/uaaclient"

require "cfoundry/errors"

module CFoundry::V1
  class Base < CFoundry::BaseClient
    include BaseClientMethods

    attr_accessor :target, :token, :proxy, :trace, :backtrace, :log

    def initialize(
        target = "https://api.cloudfoundry.com",
        token = nil)
      super
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
      get("info", :accept => :json)
    end

    def system_services
      get("services", "v1", "offerings", :content => :json, :accept => :json)
    end

    def system_runtimes
      get("info", "runtimes", :accept => :json)
    end

    # Users
    def create_token(payload, email)
      post(payload, "users", email, "tokens",
           :content => :json, :accept => :json)
    end

    # Applications
    def instances(name)
      get("apps", name, "instances", :accept => :json)[:instances]
    end

    def crashes(name)
      get("apps", name, "crashes", :accept => :json)[:crashes]
    end

    def files(name, instance, *path)
      get("apps", name, "instances", instance, "files", *path)
    end
    alias :file :files

    def stats(name)
      get("apps", name, "stats", :accept => :json)
    end

    def resource_match(fingerprints)
      post(fingerprints, "resources", :content => :json, :accept => :json)
    end

    def upload_app(name, zipfile, resources = [])
      payload = {
        :_method => "put",
        :resources => MultiJson.dump(resources),
        :application =>
          UploadIO.new(
            if zipfile.is_a? File
              zipfile
            elsif zipfile.is_a? String
              File.new(zipfile, "rb")
            end,
            "application/zip")
      }

      post(payload, "apps", name, "application")
    rescue EOFError
      retry
    end

    private

    def handle_response(response, accept)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        if accept == :json
          if response.is_a?(Net::HTTPNoContent)
            raise CFoundry::BadResponse.new(
              204,
              "Expected JSON response, got 204 No Content")
          end

          parse_json(response.body)
        else
          response.body
        end

      when Net::HTTPBadRequest, Net::HTTPForbidden, Net::HTTPNotFound,
            Net::HTTPInternalServerError, Net::HTTPNotImplemented,
            Net::HTTPBadGateway
        begin
          info = parse_json(response.body)
          return super unless info[:code]

          cls = CFoundry::APIError.error_classes[info[:code]]

          raise (cls || CFoundry::APIError).new(info[:code], info[:description])
        rescue MultiJson::DecodeError
          super
        end

      else
        super
      end
    end
  end
end
