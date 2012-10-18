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
      get("info", nil => :json)
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
        params = params_from(args)

        all_pages(
          params,
          get("v2", plural, nil => :json, :params => params))
      end

    end

    def resource_match(fingerprints)
      put(fingerprints, "v2", "resource_match", :json => :json)
    end

    def upload_app(guid, zipfile, resources = [])
      payload = {
        :resources => MultiJson.dump(resources),
        :multipart => true,
        :application =>
          if zipfile.is_a? File
            zipfile
          elsif zipfile.is_a? String
            File.new(zipfile, "rb")
          end
      }

      put(payload, "v2", "apps", guid, "bits")
    rescue RestClient::ServerBrokeConnection
      retry
    end

    def files(guid, instance, *path)
      get("v2", "apps", guid, "instances", instance, "files", *path)
    end
    alias :file :files

    def instances(guid)
      get("v2", "apps", guid, "instances", nil => :json)
    end

    def crashes(guid)
      get("v2", "apps", guid, "crashes", nil => :json)
    end

    def stats(guid)
      get("v2", "apps", guid, "stats", nil => :json)
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

    def all_pages(params, paginated)
      payload = paginated[:resources]

      while next_page = paginated[:next_url]
        paginated = request_path(
          Net::HTTP::Get, next_page, nil => :json, :params => params)

        payload += paginated[:resources]
      end

      payload
    end

    private

    def handle_response(response, accept)
      json = accept == :json

      case response.code
      when 200, 201, 204, 301, 302, 307
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
        rescue MultiJson::DecodeError
          raise CFoundry::BadResponse.new(response.code, response)
        end

      else
        raise CFoundry::BadResponse.new(response.code, response)
      end
    end

    def log_line(io, data)
      io.printf(
        "[%s]  %0.3fs  %s  %6s -> %d  %s\n",
        Time.now.strftime("%F %T"),
        data[:time],
        data[:response][:headers][:x_vcap_request_id],
        data[:request][:method].to_s.upcase,
        data[:response][:code],
        data[:request][:url])
    end
  end
end
