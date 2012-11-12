require "multi_json"
require "base64"

require "cfoundry/baseclient"
require "cfoundry/uaaclient"

require "cfoundry/errors"

module CFoundry::V2
  class Base < CFoundry::BaseClient
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


    [ :app, :organization, :space, :user, :runtime, :framework, :service,
      :domain, :route, :service_plan, :service_binding, :service_instance,
      :service_auth_token
    ].each do |obj|
      plural = "#{obj}s"

      define_method(obj) do |guid, *args|
        depth, _ = args
        depth ||= 1

        params = { :"inline-relations-depth" => depth }

        get("v2", plural, guid, :accept => :json, :params => params)
      end

      define_method(:"create_#{obj}") do |payload|
        post(payload, "v2", plural, :content => :json, :accept => :json)
      end

      define_method(:"delete_#{obj}") do |guid|
        delete("v2", plural, guid, nil => nil)
        true
      end

      define_method(:"update_#{obj}") do |guid, payload|
        put(payload, "v2", plural, guid, :content => :json, :accept => :json)
      end

      define_method(plural) do |*args|
        all_pages(
          get("v2", plural, :accept => :json, :params => params_from(args)))
      end
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
      depth, query = args
      depth ||= 1

      params = { :"inline-relations-depth" => depth }

      if query
        params[:q] = "#{query.keys.first}:#{query.values.first}"
      end

      params
    end

    def all_pages(paginated)
      payload = paginated[:resources]

      while next_page = paginated[:next_url]
        paginated = request_path(:get, next_page, nil => :json)
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
