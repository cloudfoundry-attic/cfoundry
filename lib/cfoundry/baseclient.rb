require "restclient"
require "json"

module CFoundry
  class BaseClient # :nodoc:
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

    private

    def parse_json(x)
      JSON.parse(x, :symbolize_names => true)
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
          payload = payload.to_json
        when :form
          payload = encode_params(payload, false)
        end
      end

      headers["Content-Length"] = payload ? payload.size : 0

      headers.merge!(options[:headers]) if options[:headers]

      if params
        path += "?" + encode_params(params)
      end

      req = options.dup
      req[:method] = method
      req[:url] = @target + path
      req[:headers] = headers
      req[:payload] = payload

      json = accept == :json

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

    def encode_params(hash, escape = true, parent = nil)
      hash.keys.map do |k|
        v = hash[k]
        key = parent ? "#{parent}[#{k}]" : k

        value =
          if v.is_a?(Hash)
            v.to_json
          elsif escape
            URI.escape(v.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
          else
            v
          end

        "#{key}=#{value}"
      end.join("&")
    end

    def request_with_types(method, path, options = {})
      if path.last.is_a?(Hash)
        types = path.pop
      end

      request_path(method, url(path), types, options)
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
  end
end
