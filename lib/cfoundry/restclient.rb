require "restclient"
require "json"

require "cfoundry/errors"


module CFoundry
  class RESTClient # :nodoc:
    attr_accessor :target, :token, :proxy, :trace

    def initialize(
        target = "http://api.cloudfoundry.com",
        token = nil)
      @target = target
      @token = token
    end

    # Cloud metadata
    def info
      json_get("info")
    end

    def system_services
      json_get("info", "services")
    end

    def system_runtimes
      json_get("info", "runtimes")
    end

    # Users
    def users
      json_get("users")
    end

    def create_user(payload)
      post(payload.to_json, "users")
    end

    def user(email)
      json_get("users", email)
    end

    def delete_user(email)
      delete("users", email)
      true
    end

    def update_user(email, payload)
      put(payload.to_json, "users", email)
    end

    def create_token(payload, email)
      json_post(payload.to_json, "users", email, "tokens")
    end

    # Applications
    def apps
      json_get("apps")
    end

    def create_app(payload)
      json_post(payload.to_json, "apps")
    end

    def app(name)
      json_get("apps", name)
    end

    def instances(name)
      json_get("apps", name, "instances")["instances"]
    end

    def files(name, instance, *path)
      get("apps", name, "instances", instance, "files", *path)
    end
    alias :file :files

    def update_app(name, payload)
      put(payload.to_json, "apps", name)
    end

    def delete_app(name)
      delete("apps", name)
      true
    end

    def stats(name)
      json_get("apps", name, "stats")
    end

    def check_resources(fingerprints)
      json_post(fingerprints.to_json, "resources")
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
      json_get("services")
    end

    def create_service(manifest)
      json_post(manifest.to_json, "services")
    end

    def service(name)
      json_get("services", name)
    end

    def delete_service(name)
      delete("services", name)
      true
    end

  private
    def request(type, segments, options = {})
      headers = {}
      headers["AUTHORIZATION"] = @token if @token
      headers["PROXY-USER"] = @proxy if @proxy
      headers["Content-Type"] = "application/json" # TODO: probably not always
                                                   #       and set Accept
      headers["Content-Length"] =
        options[:payload] ? options[:payload].size : 0

      req = options.dup
      req[:method] = type
      req[:url] = url(segments)
      req[:headers] = headers.merge(req[:headers] || {})

      json = req.delete :json

      RestClient::Request.execute(req) do |response, request|
        if @trace
          puts '>>>'
          puts "PROXY: #{RestClient.proxy}" if RestClient.proxy
          puts "REQUEST: #{req[:method]} #{req[:url]}"
          puts "RESPONSE_HEADERS:"
          response.headers.each do |key, value|
            puts "    #{key} : #{value}"
          end
          puts "REQUEST_HEADERS:"
          request.headers.each do |key, value|
            puts "    #{key} : #{value}"
          end
          puts "REQUEST_BODY: #{req[:payload]}" if req[:payload]
          puts "RESPONSE: [#{response.code}]"
          begin
            puts JSON.pretty_generate(JSON.parse(response.body))
          rescue
            puts "#{response.body}"
          end
          puts '<<<'
        end

        case response.code
        when 200, 204, 302
          if json
            if response.code == 204
              raise "Expected JSON response, got 204 No Content"
            end

            JSON.parse response
          else
            response
          end

        # TODO: figure out how/when the CC distinguishes these
        when 400, 403
          info = JSON.parse response
          raise Denied.new(
            info["code"],
            info["description"])

        when 404
          raise NotFound

        when 411, 500, 504
          begin
            raise_error(JSON.parse(response))
          rescue JSON::ParserError
            raise BadResponse.new(response.code, response)
          end

        else
          raise BadResponse.new(response.code, response)
        end
      end
    rescue SocketError, Errno::ECONNREFUSED => e
      raise TargetRefused, e.message
    end

    def raise_error(info)
      case info["code"]
      when 402
        raise UploadFailed.new(info["description"])
      else
        raise APIError.new(info["code"], info["description"])
      end
    end

    def get(*path)
      request(:get, path)
    end

    def delete(*path)
      request(:delete, path)
    end

    def post(payload, *path)
      request(:post, path, :payload => payload)
    end

    def put(payload, *path)
      request(:put, path, :payload => payload)
    end

    def json_get(*path)
      request(:get, path, :json => true)
    end

    def json_delete(*path)
      request(:delete, path, :json => true)
    end

    def json_post(payload, *path)
      request(:post, path, :payload => payload, :json => true)
    end

    def json_put(payload, *path)
      request(:put, path, :payload => payload, :json => true)
    end

    def url(segments)
      "#@target/#{safe_path(segments)}"
    end

    def safe_path(*segments)
      segments.flatten.collect { |x|
        URI.encode x.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
      }.join("/")
    end
  end
end
