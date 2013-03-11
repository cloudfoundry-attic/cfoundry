require "cfoundry/trace_helpers"
require "net/https"
require "net/http/post/multipart"
require "multi_json"
require "fileutils"
require "forwardable"

module CFoundry
  class BaseClient # :nodoc:
    extend Forwardable

    attr_reader :rest_client

    def_delegators :rest_client, :target, :target=, :token,
      :proxy, :proxy=, :trace, :backtrace, :backtrace=,
      :log, :log=

    def initialize(target = "https://api.cloudfoundry.com", token = nil)
      @rest_client = CFoundry::RestClient.new(target, token)
      self.trace = false
      self.backtrace = false
      self.log = false
    end

    def uaa
      @uaa ||= begin
        endpoint = info[:authorization_endpoint]

        if endpoint
          uaa = CFoundry::UAAClient.new(endpoint)
          uaa.trace = trace
          uaa.token = token
          uaa
        else
          nil
        end
      end
    end

    def password_score(password)
      uaa ? uaa.password_score(password) : :unknown
    end

    def token=(token)
      if token.is_a?(String)
        token = CFoundry::AuthToken.new(token)
      end

      @rest_client.token = token
      @uaa.token = token if @uaa
    end

    def trace=(trace)
      @rest_client.trace = trace
      @uaa.trace = trace if @uaa
    end

    # Cloud metadata
    def info
      get("info", :accept => :json)
    end

    def get(*args)
      request("GET", *args)
    end

    def delete(*args)
      request("DELETE", *args)
    end

    def post(*args)
      request("POST", *args)
    end

    def put(*args)
      request("PUT", *args)
    end

    def request(method, *args)
      if needs_token_refresh?
        token.auth_header = nil
        refresh_token!
      end

      path, options = normalize_arguments(args)
      request, response = request_raw(method, path, options)
      handle_response(response, options, request)
    end

    def request_raw(method, path, options)
      @rest_client.request(method, path, options)
    end

    def refresh_token!
      self.token = uaa.try_to_refresh_token!
    end

    def stream_url(url, &blk)
      uri = URI.parse(url)

      Net::HTTP.start(uri.host, uri.port) do |http|
        http.read_timeout = 5

        req = Net::HTTP::Get.new(uri.request_uri)
        req["Authorization"] = token.auth_header if token

        http.request(req) do |response|
          case response
          when Net::HTTPOK
            response.read_body(&blk)
          when Net::HTTPNotFound
            raise CFoundry::NotFound.new(response.body, 404)
          when Net::HTTPForbidden
            raise CFoundry::Denied.new(response.body, 403)
          else
            raise CFoundry::BadResponse.new(response.body, response.code)
          end
        end
      end
    end

    private

    def needs_token_refresh?
      token && token.auth_header && token.refresh_token && \
        token.expires_soon?
    end

    def status_is_successful?(code)
      (code >= 200) && (code < 400)
    end

    def handle_response(response, options, request)
      if status_is_successful?(response[:status].to_i)
        handle_successful_response(response, options)
      else
        handle_error_response(response, request)
      end
    end

    def handle_successful_response(response, options)
      if options[:return_response]
        response
      elsif options[:accept] == :json
        parse_json(response[:body])
      else
        response[:body]
      end
    end

    def handle_error_response(response, request)
      body_json = parse_json(response[:body])
      body_code = body_json && body_json[:code]
      code = body_code || response[:status].to_i

      if body_code
        error_class = CFoundry::APIError.error_classes[body_code] || CFoundry::APIError
        raise error_class.new(body_json[:description], body_code, request, response)
      end

      case code
        when 404
          raise CFoundry::NotFound.new(nil, code, request, response)
        when 403
          raise CFoundry::Denied.new(nil, code, request, response)
        else
          raise CFoundry::BadResponse.new(nil, code, request, response)
      end
    end

    def normalize_arguments(args)
      if args.last.is_a?(Hash)
        options = args.pop
      else
        options = {}
      end

      [normalize_path(args), options]
    end

    URI_ENCODING_PATTERN = Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")

    def normalize_path(segments)
      if segments.size == 1 && segments.first =~ /^\//
        segments.first
      else
        segments.flatten.collect { |x|
          URI.encode(x.to_s, URI_ENCODING_PATTERN)
        }.join("/")
      end
    end

    def parse_json(x)
      if x.empty?
        raise MultiJson::DecodeError.new("Empty JSON string", [], "")
      else
        MultiJson.load(x, :symbolize_keys => true)
      end
    rescue MultiJson::DecodeError
      nil
    end
  end
end
