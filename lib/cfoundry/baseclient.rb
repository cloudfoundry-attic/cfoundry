require "restclient"
require "multi_json"

module CFoundry
  class BaseClient # :nodoc:
    LOG_FILE = File.expand_path("~/.cfoundry.log")
    LOG_LENGTH = 10

    attr_accessor :trace, :no_backtrace

    def initialize(target, token = nil)
      @target = target
      @token = token
      @trace = false
      @no_backtrace = false
    end

    def request_path(method, path, types = {}, options = {})
      path = url(path) if path.is_a?(Array)

      unless types.empty?
        if params = types.delete(:params)
          options[:params] = params
        end

        if types.size > 1
          raise "request types must contain only one Content-Type => Accept"
        end

        options[:type] = types.keys.first
        options[:accept] = types.values.first
      end

      request(method, path, options)
    end

    # grab the metadata from a token that looks like:
    #
    # bearer (base64 ...)
    def token_data
      tok = Base64.decode64(@token.sub(/^bearer\s+/, ""))
      tok.sub!(/\{.+?\}/, "") # clear algo
      MultiJson.load(tok[/\{.+?\}/], :symbolize_keys => true)

    # normally i don't catch'em all, but can't expect all tokens to be the
    # proper format, so just silently fail as this is not critical
    rescue
      {}
    end

    private

    def parse_json(x)
      MultiJson.load(x, :symbolize_keys => true)
    end

    def request(method, path, options = {})
      accept = options.delete(:accept)
      type = options.delete(:type)
      payload = options.delete(:payload)
      params = options.delete(:params)

      headers = {}
      headers["Authorization"] = @token if @token
      headers["Proxy-User"] = @proxy if @proxy

      if accept_type = mimetype(accept)
        headers["Accept"] = accept_type
      end

      if content_type = mimetype(type)
        headers["Content-Type"] = content_type
      end

      unless payload.is_a?(String)
        case type
        when :json
          payload = MultiJson.dump(payload)
        when :form
          payload = encode_params(payload)
        end
      end

      headers["Content-Length"] = payload ? payload.size : 0

      headers.merge!(options[:headers]) if options[:headers]

      if params
        uri = URI.parse(path)
        path += (uri.query ? "&" : "?") + encode_params(params)
      end

      req = options.dup
      req[:method] = method
      req[:url] = @target + path
      req[:headers] = headers
      req[:payload] = payload

      json = accept == :json

      RestClient::Request.execute(req) do |response, request|
        print_trace(req, request, response, caller) if @trace
        log_request(req, response)
        handle_response(response, accept)
      end
    rescue SocketError, Errno::ECONNREFUSED => e
      raise TargetRefused, e.message
    end

    def mimetype(type)
      case type
      when String
        type
      when :json
        "application/json"
      when :form
        "application/x-www-form-urlencoded"
      when nil
        nil
      # return request headers (not really Accept)
      when :headers
        nil
      else
        raise "unknown mimetype #{type.inspect}"
      end
    end

    def encode_params(hash, escape = true)
      hash.keys.map do |k|
        v = hash[k]
        v = MultiJson.dump(v) if v.is_a?(Hash)
        v = URI.escape(v.to_s, /[^#{URI::PATTERN::UNRESERVED}]/) if escape
        "#{k}=#{v}"
      end.join("&")
    end

    def request_with_types(method, path, options = {})
      if path.last.is_a?(Hash)
        types = path.pop
      end

      request_path(method, url(path), types || {}, options)
    end

    def get(*path)
      request_with_types(:get, path)
    end

    def delete(*path)
      request_with_types(:delete, path)
    end

    def post(payload, *path)
      request_with_types(:post, path, :payload => payload)
    end

    def put(payload, *path)
      request_with_types(:put, path, :payload => payload)
    end

    def url(segments)
      "/#{safe_path(segments)}"
    end

    def safe_path(*segments)
      segments.flatten.collect { |x|
        URI.encode x.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
      }.join("/")
    end

    def log_request(req, response)
      file = File.expand_path(LOG_FILE)

      if File.exists?(file)
        log = File.readlines(file).last(LOG_LENGTH - 1)
      end

      File.open(file, "w") do |io|
        log.each { |l| io.print l } if log
        io.puts log_line(req, response.headers[:x_vcap_request_id])
      end
    end

    def log_line(req, id)
      "#{Time.now.strftime("%F %T")}  #{id}  #{req[:method].to_s.upcase.ljust(6)}  #{req[:url]}"
    end

    def print_trace(req, request, response, locs)
      $stderr.puts ">>>"
      $stderr.puts "PROXY: #{RestClient.proxy}" if RestClient.proxy
      $stderr.puts "REQUEST: #{req[:method]} #{req[:url]}"
      $stderr.puts "RESPONSE_HEADERS:"
      response.headers.each do |key, value|
        $stderr.puts "    #{key} : #{value}"
      end
      $stderr.puts "REQUEST_HEADERS:"
      request.headers.each do |key, value|
        $stderr.puts "    #{key} : #{value}"
      end
      $stderr.puts "REQUEST_BODY: #{req[:payload]}" if req[:payload]
      $stderr.puts "RESPONSE: [#{response.code}]"
      begin
        parsed_body = MultiJson.load(response.body)
        $stderr.puts MultiJson.dump(parsed_body, :pretty => true)
      rescue
        $stderr.puts "#{response.body}"
      end
      $stderr.puts "<<<"

      return if @no_backtrace

      interesting_locs = locs.drop_while { |loc|
        loc =~ /\/(cfoundry\/|restclient\/|net\/http)/
      }

      $stderr.puts "--- backtrace:"

      $stderr.puts "... (boring)" unless locs == interesting_locs

      trimmed_locs = interesting_locs[0..5]

      trimmed_locs.each do |loc|
        $stderr.puts "=== #{loc}"
      end

      $stderr.puts "... (trimmed)" unless trimmed_locs == interesting_locs
    end

    def handle_response(response, accept)
      json = accept == :json

      case response.code
      when 200, 201, 204, 302
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

      when 404
        raise CFoundry::NotFound

      else
        raise CFoundry::BadResponse.new(response.code, response)
      end
    end
  end
end
