require "net/https"
require "multi_json"
require "yaml"

module CFoundry
  # Base class for CFoundry errors (not from the server).
  class Error < RuntimeError
  end

  class Deprecated < Error
  end

  class Mismatch < Error
    def initialize(expected, got)
      @expected = expected
      @got = got
    end

    def to_s
      "Invalid value type; expected #{@expected.inspect}, got #{@got.inspect}"
    end
  end

  class InvalidTarget < Error
    attr_reader :target

    def initialize(target)
      @target = target
    end

    def to_s
      "Invalid target URI: #{@target}"
    end
  end

  class TargetRefused < Error
    # Error message.
    attr_reader :message

    # Message varies as this represents various network errors.
    def initialize(message)
      @message = message
    end

    # Exception message.
    def to_s
      "target refused connection (#@message)"
    end
  end

  class Timeout < Timeout::Error
    attr_reader :method, :uri, :parent

    def initialize(method, uri, parent = nil)
      @method = method
      @uri = uri
      @parent = parent
      super(to_s)
    end

    def to_s
      "#{method} #{uri} timed out"
    end
  end

  # Exception representing errors returned by the API.
  class APIError < RuntimeError
    include TraceHelpers

    class << self
      def error_classes
        @error_classes ||= {}
      end
    end

    attr_reader :error_code, :description, :request, :response

    # Create an APIError with a given request and response.
    def initialize(description = nil, error_code = nil, request = nil, response = nil)
      @response = response
      @request = request
      @error_code = error_code || (response ? response[:status] : nil)
      @description = description || parse_description
    end

    # Exception message.
    def to_s
      "#{error_code}: #{description}"
    end

    def request_trace
      super(request)
    end

    def response_trace
      super(response)
    end

    private

    def parse_description
      return unless response

      parse_json(response[:body])[:description]
    rescue MultiJson::DecodeError
      response[:body]
    end

    def parse_json(x)
      if x.empty?
        raise MultiJson::DecodeError.new("Empty JSON string", [], "")
      else
        MultiJson.load(x, :symbolize_keys => true)
      end
    end
  end

  class NotFound < APIError
  end

  class Denied < APIError
  end

  class Unauthorized < APIError
  end

  class BadResponse < APIError
  end

  class UAAError < APIError
  end

  def self.define_error(class_name, code)
    base =
      case class_name
      when /NotFound$/
        NotFound
      else
        APIError
      end

    klass =
      if const_defined?(class_name)
        const_get(class_name)
      else
        Class.new(base)
      end

    APIError.error_classes[code] = klass

    unless const_defined?(class_name)
      const_set(class_name, klass)
    end
  end

  VENDOR_DIR = File.expand_path("../../../vendor", __FILE__)

  %w{errors/v1.yml errors/v2.yml}.each do |errors|
    YAML.load_file("#{VENDOR_DIR}/#{errors}").each do |code, meta|
      define_error(meta["name"], code)
    end
  end
end
