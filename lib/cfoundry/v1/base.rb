require "multi_json"

require "cfoundry/baseclient"
require "cfoundry/uaaclient"

require "cfoundry/errors"

module CFoundry::V1
  class Base < CFoundry::BaseClient
    include BaseClientMethods

    def system_services
      get("services", "v1", "offerings", :content => :json, :accept => :json)
    end

    def system_runtimes
      get("info", "runtimes", :accept => :json)
    end

    # Users
    def create_user(payload)
      # no JSON response
      post("users", :content => :json, :payload => payload)
    end

    def create_token(payload, email)
      post("users", email, "tokens", :content => :json, :accept => :json, :payload => payload)
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
      post("resources", :content => :json, :accept => :json, :payload => fingerprints)
    end

    def upload_app(name, zipfile = nil, resources = [])
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

      post("apps", name, "application", :payload => payload)
    rescue EOFError
      retry
    end
  end
end
