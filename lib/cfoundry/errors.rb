module CFoundry
  # Exception representing errors returned by the API.
  class APIError < RuntimeError
    class << self
      # Generic error code for the exception.
      attr_reader :error_code

      # Generic description for the exception.
      attr_reader :description

      private

      def setup(code, description = nil)
        @error_code = code
        @description = description
      end
    end

    # Create an APIError with a given error code and description.
    def initialize(error_code = nil, description = nil)
      @error_code = error_code
      @description = description
    end

    # A number representing the error.
    def error_code
      @error_code || self.class.error_code
    end

    # A description of the error.
    def description
      @description || self.class.description
    end

    # Exception message.
    def to_s
      if error_code
        "#{error_code}: #{description}"
      else
        description
      end
    end
  end

  # Generic exception thrown when accessing something that doesn't exist (e.g.
  # getting info of unknown application).
  class NotFound < APIError
    setup(404, "entity not found or inaccessible")
  end

  # Lower-level exception for when we cannot connect to the target.
  class TargetRefused < APIError
    @description = "target refused connection"

    # Error message.
    attr_reader :message

    # Message varies as this represents various network errors.
    def initialize(message)
      @message = message
    end

    # Exception message.
    def to_s
      "#{description} (#{@message})"
    end
  end

  # Exception raised when an application payload fails to upload.
  class UploadFailed < APIError
    setup(402)
  end

  # Exception raised when access is denied to something, either because the
  # user is not logged in or is not an administrator.
  class Denied < APIError
    # Specific error code.
    attr_reader :error_code

    # Specific description.
    attr_reader :description

    # Initialize, with a default error code and message.
    def initialize(
        error_code = 200,
        description = "Operation not permitted")
      @error_code = error_code
      @description = description
    end
  end

  # Exception raised when the response is unexpected; usually from a server
  # error.
  class BadResponse < StandardError
    # Initialize, with the HTTP response code and body.
    def initialize(code, body = nil)
      @code = code
      @body = body
    end

    # Exception message.
    def to_s
      "target failed to handle our request due to an internal error (#{@code})"
    end
  end
end
