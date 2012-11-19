require "multi_json"

require "cfoundry/baseclient"
require "cfoundry/uaaclient"

require "cfoundry/errors"

module CFoundry::V2
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

    def resource_match(fingerprints)
      put(fingerprints, "v2", "resource_match",
          :content => :json, :accept => :json)
    end

    def upload_app(guid, zipfile, resources = [])
      payload = {
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

      put(payload, "v2", "apps", guid, "bits")
    rescue EOFError
      retry
    end

    def files(guid, instance, *path)
      get("v2", "apps", guid, "instances", instance, "files", *path)
    end
    alias :file :files

    def stream_file(guid, instance, *path)
      redirect =
        request_with_options(
          Net::HTTP::Get,
          ["v2", "apps", guid, "instances", instance, "files", *path],
          :return_response => true)

      if loc = redirect["location"]
        uri = URI.parse(loc + "&tail")

        Net::HTTP.start(uri.host, uri.port) do |http|
          req = Net::HTTP::Get.new(uri.request_uri)
          req["Authorization"] = @token

          http.request(req) do |response|
            response.read_body do |chunk|
              yield chunk
            end
          end
        end
      else
        yield redirect.body
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


    def params_from(args)
      options, _ = args
      options ||= {}
      options[:depth] ||= 1

      params = {}
      options.each do |k, v|
        case k
        when :depth
          params[:"inline-relations-depth"] = v
        when :query
          params[:q] = v.join(":")
        end
      end

      params
    end

    def all_pages(paginated)
      payload = paginated[:resources]

      while next_page = paginated[:next_url]
        paginated = request_path(Net::HTTP::Get, next_page, :accept => :json)
        payload += paginated[:resources]
      end

      payload
    end

    private

    def handle_response(response, accept)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        if accept == :headers
          return sane_headers(response)
        end

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

      when Net::HTTPBadRequest, Net::HTTPUnauthorized, Net::HTTPNotFound,
            Net::HTTPNotImplemented, Net::HTTPServiceUnavailable
        begin
          info = parse_json(response.body)
          return super unless info[:code]

          cls = CFoundry::APIError.v2_classes[info[:code]]

          raise (cls || CFoundry::APIError).new(info[:code], info[:description])
        rescue MultiJson::DecodeError
          super
        end

      else
        super
      end
    end

    def log_line(io, data)
      io.printf(
        "[%s]  %0.3fs  %s  %6s -> %d  %s\n",
        Time.now.strftime("%F %T"),
        data[:time],
        data[:response][:headers]["x-vcap-request-id"],
        data[:request][:method].to_s.upcase,
        data[:response][:code],
        data[:request][:url])
    end
  end
end
