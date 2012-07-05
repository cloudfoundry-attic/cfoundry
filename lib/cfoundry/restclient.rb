require "json"

require "cfoundry/baseclient"


module CFoundry
  class RESTClient < BaseClient
    attr_accessor :target, :token, :proxy, :trace

    def initialize(
        target = "https://api.cloudfoundry.com",
        token = nil)
      @target = target
      @token = token
    end

    # Cloud metadata
    def info
      get("info", nil => :json)
    end

    def system_services
      get("info", "services", nil => :json)
    end

    def system_runtimes
      get("info", "runtimes", nil => :json)
    end

    # Users
    def users
      get("users", nil => :json)
    end

    def create_user(payload)
      post(payload, "users")
    end

    def user(email)
      get("users", email, nil => :json)
    end

    def delete_user(email)
      delete("users", email, nil => :json)
      true
    end

    def update_user(email, payload)
      put(payload, "users", email, :json => nil)
    end

    def create_token(payload, email)
      post(payload, "users", email, "tokens", :json => :json)
    end

    # Applications
    def apps
      get("apps", nil => :json)
    end

    def create_app(payload)
      post(payload, "apps", :json => :json)
    end

    def app(name)
      get("apps", name, nil => :json)
    end

    def instances(name)
      get("apps", name, "instances", nil => :json)[:instances]
    end

    def files(name, instance, *path)
      get("apps", name, "instances", instance, "files", *path)
    end
    alias :file :files

    def update_app(name, payload)
      put(payload, "apps", name, :json => nil)
    end

    def delete_app(name)
      # TODO: no JSON response?
      delete("apps", name)
      true
    end

    def stats(name)
      get("apps", name, "stats", nil => :json)
    end

    def check_resources(fingerprints)
      post(fingerprints, "resources", :json => :json)
    end

    def upload_app(name, zipfile, resources = [])
      payload = {
        :_method => "put",
        :resources => resources.to_json,
        :multipart => true,
        :application =>
          if zipfile.is_a? File
            zipfile
          elsif zipfile.is_a? String
            File.new(zipfile, "rb")
          end
      }

      post(payload, "apps", name, "application")
    rescue RestClient::ServerBrokeConnection
      retry
    end

    # Services
    def services
      get("services", nil => :json)
    end

    def create_service(manifest)
      post(manifest, "services", :json => :json)
    end

    def service(name)
      get("services", name, nil => :json)
    end

    def delete_service(name)
      delete("services", name, nil => :json)
      true
    end
  end
end
