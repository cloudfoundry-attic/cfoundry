require "multi_json"

require "cfoundry/baseclient"
require "cfoundry/uaaclient"

require "cfoundry/errors"

module CFoundry::V2
  class Base < CFoundry::BaseClient
    include BaseClientMethods

    def resource_match(fingerprints)
      put("v2", "resource_match", :content => :json, :accept => :json, :payload => fingerprints)
    end

    def upload_app(guid, zipfile = nil, resources = [])
      payload = {}
      payload[:resources] = MultiJson.dump(resources)

      if zipfile
        payload[:application] =
          UploadIO.new(
            if zipfile.is_a? File
              zipfile
            elsif zipfile.is_a? String
              File.new(zipfile, "rb")
            end,
            "application/zip")
      end

      response = put("v2", "apps", guid, "bits",
        :payload => payload,
        :params => {"async" => "true"})

      if response.present?
        response_json = JSON.parse(response)
        poll_upload_until_finished(response_json['metadata']['guid'])
      end
    rescue EOFError
      retry
    end

    def poll_upload_until_finished(guid)
      while true
        response = get("v2", "jobs", guid, :accept => :json)
        break if response[:entity][:status] == "finished"

        if response[:entity][:status] == "failed"
          raise CFoundry::BadResponse
        end
        sleep 0.2
      end
    end

    def files(guid, instance, *path)
      get("v2", "apps", guid, "instances", instance, "files", *path)
    end

    alias :file :files

    def stream_file(guid, instance, *path, &blk)
      path_and_options = path + [{:return_response => true, :follow_redirects => false}]
      redirect = get("v2", "apps", guid, "instances", instance, "files", *path_and_options)

      if location = redirect[:headers]["location"]
        stream_url(location + "&tail", &blk)
      else
        yield redirect[:body]
      end
    end

    def instances(guid)
      get("v2", "apps", guid, "instances", :accept => :json)
    end

    def crashes(guid)
      get("v2", "apps", guid, "crashes", :accept => :json)
    end

    def stats(guid)
      get("v2", "apps", guid, "stats", :accept => :json)
    end

    def env(guid)
      get("v2", "apps", guid, "env", :accept => :json)
    end

    def update_app(guid, diff)
      put("v2", "apps", guid,
          :content => :json,
          :payload => diff,
          :return_response => true)
    end

    def for_each(paginated, &block)
      paginated[:resources].each &block

      while (next_page = paginated[:next_url])
        paginated = get(next_page, :accept => :json)
        paginated[:resources].each &block
      end
    end

    def all_pages(paginated)
      payload = []
      for_each(paginated) do |resource|
        payload << resource
      end
      payload
    end
  end
end
