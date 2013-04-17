require File.expand_path("../../concerns/login_helpers", __FILE__)

module CFoundry::V2
  # The primary API entrypoint. Wraps a BaseClient to provide nicer return
  # values. Initialize with the target and, optionally, an auth token. These
  # are the only two internal states.
  class Client
    include ClientMethods, CFoundry::LoginHelpers

    # Internal BaseClient instance. Normally won't be touching this.
    attr_reader :base

    # [Organization] Currently targeted organization.
    attr_accessor :current_organization

    # [Space] Currently targeted space.
    attr_accessor :current_space


    # Create a new Client for interfacing with the given target.
    #
    # A token may also be provided to skip the login step.
    def initialize(target = "http://api.cloudfoundry.com", token = nil)
      @base = Base.new(target, token)
    end

    def version
      2
    end

    # The current target URL of the client.
    def target
      @base.target
    end

    # Current authentication token.
    def token
      @base.token
    end

    # Set the authentication token.
    def token=(token)
      @base.token = token
    end

    # Current proxy user. Usually nil.
    def proxy
      @base.proxy
    end

    # Set the proxy user for the client. Must be authorized as an
    # administrator for this to have any effect.
    def proxy=(email)
      @base.proxy = email
    end

    # Current http proxy URI. Usually nil.
    def http_proxy
      @base.http_proxy
    end

    # Set the http proxy URI.
    def http_proxy=(uri)
      @base.http_proxy = uri
    end

    # Current https proxy URI. Usually nil.
    def https_proxy
      @base.https_proxy
    end

    # Set the https proxy URI.
    def https_proxy=(uri)
      @base.https_proxy = uri
    end

    # Is the client tracing API requests?
    def trace
      @base.trace
    end

    # Set the tracing flag; if true, API requests and responses will be
    # printed out.
    def trace=(bool)
      @base.trace = bool
    end

    # The current log. See +log=+.
    def log
      @base.log
    end

    # Set the logging mode. Mode can be one of:
    #
    # [+String+] Name of a file to log the last 10 requests to.
    # [+Array+]  Array to append with log data (a Hash).
    # [+IO+]     An IO object to write to.
    # [+false+]  No logging.
    def log=(mode)
      @base.log = mode
    end

    # The currently authenticated user.
    def current_user
      return unless token

      token_data = @base.token.token_data
      if guid = token_data[:user_id]
        user = user(guid)
        user.emails = [{ :value => token_data[:email] }]
        user
      end
    end

    # Cloud metadata
    def info
      @base.info
    end

    def login(username, password)
      @current_organization = nil
      @current_space = nil
      super
    end

    def register(email, password)
      uaa_user = @base.uaa.add_user(email, password)
      cc_user = user
      cc_user.guid = uaa_user['id']
      cc_user.create!
      cc_user
    end

    # Clear client token. No requests are made for this.
    def logout
      @base.token = nil
    end

    # Is an authentication token set on the client?
    def logged_in?
      !!@base.token
    end

    def query_target(klass)
      if klass.scoped_space && space = current_space
        space
      elsif klass.scoped_organization && org = current_organization
        org
      else
        self
      end
    end

    def stream_url(url, &blk)
      @base.stream_url(url, &blk)
    end
  end
end
