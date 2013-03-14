require "multi_json"
require "tmpdir"

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
      use_or_create_empty_zipfile(zipfile) do |zipfile|
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
      end
    rescue EOFError
      retry
    end

    private

    def use_or_create_empty_zipfile(zipfile)
      Dir.mktmpdir do |working_dir|
        zip_path = "#{working_dir}/empty_zip.zip"

        zipfile ||= Dir.mktmpdir do |zip_dir|
          File.new("#{zip_dir}/.__empty_file", "wb").close
          CFoundry::Zip.pack(zip_dir, zip_path)
          zip_path
        end

        yield zipfile
      end
    end
  end
end
