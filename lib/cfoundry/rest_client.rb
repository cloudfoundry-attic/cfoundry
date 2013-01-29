require "cfoundry/trace_helpers"
require "net/https"
require "net/http/post/multipart"
require "multi_json"
require "fileutils"

module CFoundry
  class RestClient
    include CFoundry::TraceHelpers

    LOG_LENGTH = 10

    HTTP_METHODS = {
      "GET" => Net::HTTP::Get,
      "PUT" => Net::HTTP::Put,
      "POST" => Net::HTTP::Post,
      "DELETE" => Net::HTTP::Delete,
      "HEAD" => Net::HTTP::Head,
    }

    DEFAULT_OPTIONS = {
      :follow_redirects => true
    }

    attr_reader :target

    attr_accessor :trace, :backtrace, :log, :request_id, :token, :target, :proxy

    def initialize(target, token = nil)
      @target = target
      @token = token
      @trace = false
      @backtrace = false
      @log = false
    end

    def request(method, path, options = {})
      request_uri(method, construct_url(path), DEFAULT_OPTIONS.merge(options))
    end

    def generate_headers(payload, options)
      headers = {}

      if payload.is_a?(String)
        headers["Content-Length"] = payload.size
      elsif !payload
        headers["Content-Length"] = 0
      end

      headers["X-Request-Id"] = @request_id if @request_id
      headers["Authorization"] = @token.auth_header if @token
      headers["Proxy-User"] = @proxy if @proxy

      if accept_type = mimetype(options[:accept])
        headers["Accept"] = accept_type
      end

      if content_type = mimetype(options[:content])
        headers["Content-Type"] = content_type
      end

      headers.merge!(options[:headers]) if options[:headers]
      headers
    end

    private

    def request_uri(method, uri, options = {})
      uri = URI.parse(uri)

      # keep original options in case there's a redirect to follow
      original_options = options.dup
      payload = options[:payload]

      if params = options[:params]
        if uri.query
          uri.query += "&" + encode_params(params)
        else
          uri.query = encode_params(params)
        end
      end

      unless payload.is_a?(String)
        case options[:content]
          when :json
            payload = MultiJson.dump(payload)
          when :form
            payload = encode_params(payload)
        end
      end

      method_class = get_method_class(method)
      if payload.is_a?(Hash)
        multipart = method_class.const_get(:Multipart)
        request = multipart.new(uri.request_uri, payload)
      else
        request = method_class.new(uri.request_uri)
        request.body = payload if payload
      end

      headers = generate_headers(payload, options)

      request_hash = {
        :url => uri.to_s,
        :method => method,
        :headers => headers,
        :body => payload
      }

      print_request(request_hash) if @trace

      add_headers(request, headers)

      # TODO: test http proxies
      http = Net::HTTP.new(uri.host, uri.port)

      # TODO remove this when staging returns streaming responses
      http.read_timeout = 300

      if uri.is_a?(URI::HTTPS)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      before = Time.now
      http.start do
        response = http.request(request)
        time = Time.now - before

        response_hash = {
          :headers => sane_headers(response),
          :status => response.code,
          :body => response.body
        }

        print_response(response_hash) if @trace
        print_backtrace(caller) if @trace

        log_request(time, request, response)

        if response.is_a?(Net::HTTPRedirection) && options[:follow_redirects]
          request_uri("GET", response["location"], original_options)
        else
          return request_hash, response_hash
        end
      end
    rescue ::Timeout::Error => e
      raise Timeout.new(method, uri, e)
    rescue SocketError, Errno::ECONNREFUSED => e
      raise TargetRefused, e.message
    end

    def construct_url(path)
      path = "/#{path}" unless path[0] == ?\/
      target + path
    end

    def get_method_class(method_string)
      HTTP_METHODS[method_string.upcase]
    end

    def add_headers(request, headers)
      headers.each { |key, value| request[key] = value }
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
      $stderr.puts request_trace(request)
    end

    def print_response(response)
      $stderr.puts response_trace(response)
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

    def sane_headers(obj)
      hds = {}

      obj.each_header do |k, v|
        hds[k] = v
      end

      hds
    end
  end
end
