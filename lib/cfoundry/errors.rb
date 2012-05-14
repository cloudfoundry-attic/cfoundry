module CFoundry
  class APIError < RuntimeError
    class << self
      attr_reader :error_code, :description

      def setup(code, description = nil)
        @error_code = code
        @description = description
      end
    end

    def initialize(error_code = nil, description = nil)
      @error_code = error_code
      @description = description
    end

    def error_code
      @error_code || self.class.error_code
    end

    def description
      @description || self.class.description
    end

    def to_s
      if error_code
        "#{error_code}: #{description}"
      else
        description
      end
    end
  end

  class NotFound < APIError
    setup(404, "entity not found or inaccessible")
  end

  class TargetRefused < APIError
    @description = "target refused connection"

    attr_reader :message

    def initialize(message)
      @message = message
    end

    def to_s
      "#{description} (#{@message})"
    end
  end

  class UploadFailed < APIError
    setup(402)
  end

  class Denied < APIError
    attr_reader :error_code, :description

    def initialize(
        error_code = 200,
        description = "Operation not permitted")
      @error_code = error_code
      @description = description
    end
  end

  class BadResponse < StandardError
    def initialize(code, body = nil)
      @code = code
      @body = body
    end

    def to_s
      "target failed to handle our request due to an internal error (#{@code})"
    end
  end
end
