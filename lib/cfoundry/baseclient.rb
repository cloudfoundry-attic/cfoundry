require "net/https"
require "net/http/post/multipart"
require "multi_json"
require "fileutils"

module CFoundry
  class BaseClient # :nodoc:
    LOG_LENGTH = 10

    attr_accessor :trace, :backtrace, :log

    def initialize(target, token = nil)
      @target = target
      @token = token
      @trace = false
      @backtrace = false
      @log = false
    end

    def request_path(method, path, options = {})
      path = url(path) if path.is_a?(Array)

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
      if x.empty?
        raise MultiJson::DecodeError.new("Empty JSON string", [], "")
      else
        MultiJson.load(x, :symbolize_keys => true)
      end
    end

    def request(method, path, options = {})
      request_uri(URI.parse(@target + path), method, options)
    end

    def request_uri(uri, method, options = {})
      uri = URI.parse(@target + uri.to_s) unless uri.host

      # keep original options in case there's a redirect to follow
      original_options = options.dup

      accept = options.delete(:accept)
      content = options.delete(:content)
      payload = options.delete(:payload)
      params = options.delete(:params)
      return_headers = options.delete(:return_headers)
      return_response = options.delete(:return_response)

      headers = {}
      headers["Authorization"] = @token if @token
      headers["Proxy-User"] = @proxy if @proxy

      if accept_type = mimetype(accept)
        headers["Accept"] = accept_type
      end

      if content_type = mimetype(content)
        headers["Content-Type"] = content_type
      end

      unless payload.is_a?(String)
        case content
        when :json
          payload = MultiJson.dump(payload)
        when :form
          payload = encode_params(payload)
        end
      end

      if payload.is_a?(String)
        headers["Content-Length"] = payload.size
      elsif !payload
        headers["Content-Length"] = 0
      end

      headers.merge!(options[:headers]) if options[:headers]

      if params
        if uri.query
          uri.query += "&" + encode_params(params)
        else
          uri.query = encode_params(params)
        end
      end

      if payload && payload.is_a?(Hash)
        multipart = method.const_get(:Multipart)
        request = multipart.new(uri.request_uri, payload)
      else
        request = method.new(uri.request_uri)
        request.body = payload if payload
      end

      request["Authorization"] = @token if @token
      request["Proxy-User"] = @proxy if @proxy

      headers.each do |k, v|
        request[k] = v
      end

      # TODO: test http proxies
      http = Net::HTTP.new(uri.host, uri.port)

      if uri.is_a?(URI::HTTPS)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      print_request(request) if @trace

      before = Time.now
      http.start do
        response = http.request(request)
        time = Time.now - before

        print_response(response) if @trace
        print_backtrace(caller) if @trace

        log_request(time, request, response)

        if return_headers
          sane_headers(response)
        elsif return_response
          response
        elsif [Net::HTTP::Get, Net::HTTP::Head].include?(method) && \
            response.is_a?(Net::HTTPRedirection)
          request_uri(URI.parse(response["location"]), method, original_options)
        else
          handle_response(response, accept)
        end
      end
    rescue SocketError, Errno::ECONNREFUSED => e
      raise TargetRefused, e.message
    end

    def mimetype(content)
      case content
      when String
        content
      when :json
        "application/json"
      when :form
        "application/x-www-form-urlencoded"
      when nil
        nil
      # return request headers (not really Accept)
      else
        raise CFoundry::Error, "Unknown mimetype '#{content.inspect}'"
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

    def request_with_options(method, path, options = {})
      options.merge!(path.pop) if path.last.is_a?(Hash)

      request_path(method, url(path), options)
    end

    def get(*path)
      request_with_options(Net::HTTP::Get, path)
    end

    def delete(*path)
      request_with_options(Net::HTTP::Delete, path)
    end

    def post(payload, *path)
      request_with_options(Net::HTTP::Post, path, :payload => payload)
    end

    def put(payload, *path)
      request_with_options(Net::HTTP::Put, path, :payload => payload)
    end

    def url(segments)
      "/#{safe_path(segments)}"
    end

    def safe_path(*segments)
      segments.flatten.collect { |x|
        URI.encode x.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
      }.join("/")
    end

    def log_data(time, request, response)
      { :time => time,
        :request => {
          :method => request.method,
          :url => request.path,
          :headers => sane_headers(request)
        },
        :response => {
          :code => response.code,
          :headers => sane_headers(response)
        }
      }
    end

    def log_line(io, data)
      io.printf(
        "[%s]  %0.3fs  %6s -> %d  %s\n",
        Time.now.strftime("%F %T"),
        data[:time],
        data[:request][:method].to_s.upcase,
        data[:response][:code],
        data[:request][:url])
    end

    def log_request(time, request, response)
      return unless @log

      data = log_data(time, request, response)

      case @log
      when IO
        log_line(@log, data)
        return
      when String
        if File.exists?(@log)
          log = File.readlines(@log).last(LOG_LENGTH - 1)
        elsif !File.exists?(File.dirname(@log))
          FileUtils.mkdir_p(File.dirname(@log))
        end

        File.open(@log, "w") do |io|
          log.each { |l| io.print l } if log
          log_line(io, data)
        end

        return
      end

      if @log.respond_to?(:call)
        @log.call(data)
        return
      end

      if @log.respond_to?(:<<)
        @log << data
        return
      end
    end

    def print_request(request)
      $stderr.puts ">>>"
      $stderr.puts "REQUEST: #{request.method} #{request.path}"
      $stderr.puts "REQUEST_HEADERS:"
      request.each_header do |key, value|
        $stderr.puts "  #{key} : #{value}"
      end
      $stderr.puts "REQUEST_BODY: #{request.body}" if request.body
    end

    def print_response(response)
      $stderr.puts "RESPONSE: [#{response.code}]"
      $stderr.puts "RESPONSE_HEADERS:"
      response.each_header do |key, value|
        $stderr.puts "  #{key} : #{value}"
      end
      begin
        parsed_body = MultiJson.load(response.body)
        $stderr.puts MultiJson.dump(parsed_body, :pretty => true)
      rescue
        $stderr.puts "#{response.body}"
      end
      $stderr.puts "<<<"
    end

    def print_backtrace(locs)
      return unless @backtrace

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
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
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

      when Net::HTTPNotFound
        raise CFoundry::NotFound(response.code, response.body)

      when Net::HTTPForbidden
        raise CFoundry::Denied.new(response.code, response.body)

      else
        raise CFoundry::BadResponse.new(response.code, response.body)
      end
    end

    def sane_headers(obj)
      hds = {}

      obj.each_header do |k, v|
        hds[k] = v
      end

      hds
    end
  end
end
