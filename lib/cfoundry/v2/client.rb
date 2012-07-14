require "cfoundry/v2/base"

require "cfoundry/v2/app"
require "cfoundry/v2/framework"
require "cfoundry/v2/organization"
require "cfoundry/v2/runtime"
require "cfoundry/v2/service"
require "cfoundry/v2/service_binding"
require "cfoundry/v2/service_instance"
require "cfoundry/v2/service_plan"
require "cfoundry/v2/space"
require "cfoundry/v2/user"

module CFoundry::V2
  # The primary API entrypoint. Wraps a BaseClient to provide nicer return
  # values. Initialize with the target and, optionally, an auth token. These
  # are the only two internal states.
  class Client
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

    # The current target URL of the client.
    def target
      @base.target
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

    # Is the client tracing API requests?
    def trace
      @base.trace
    end

    # Set the tracing flag; if true, API requests and responses will be
    # printed out.
    def trace=(bool)
      @base.trace = bool
    end

    # The currently authenticated user.
    def current_user
      if user = info[:user]
        user(user)
      end
    end

    # Cloud metadata
    def info
      @base.info
    end

    # Login prompts
    def login_prompts
      if @base.uaa
        @base.uaa.prompts
      else
        { :username => ["text", "Email"],
          :password => ["password", "Password"]
        }
      end
    end

    # Authenticate with the target. Sets the client token.
    #
    # Credentials is a hash, typically containing :username and :password
    # keys.
    #
    # The values in the hash should mirror the prompts given by
    # `login_prompts`.
    def login(credentials)
      @current_organization = nil
      @current_space = nil

      @base.token =
        if @base.uaa
          @base.uaa.authorize(credentials)
        else
          @base.create_token(
            { :password => credentials[:password] },
            credentials[:username])[:token]
        end
    end

    # Clear client token. No requests are made for this.
    def logout
      @base.token = nil
    end

    # Is an authentication token set on the client?
    def logged_in?
      !!@base.token
    end


    [ :app, :organization, :app_space, :user, :runtime, :framework,
      :service, :service_plan, :service_binding, :service_instance
    ].each do |singular|
      klass = singular.to_s.capitalize.gsub(/(.)_(.)/) do
        $1 + $2.upcase
      end

      plural = :"#{singular}s"

      define_method(singular) do |*args|
        id, _ = args
        CFoundry::V2.const_get(klass).new(id, self)
      end

      define_method(plural) do |*args|
        depth, query = args
        depth ||= 1

        @base.send(plural, depth, query)[:resources].collect do |json|
          send(:"make_#{singular}", json)
        end
      end

      define_method(:"#{singular}_from") do |path|
        uri = URI.parse(path)

        if uri.query
          uri.query += "&inline-relations-depth=1"
        else
          uri.query = "inline-relations-depth=1"
        end

        send(
          :"make_#{singular}",
          @base.request_path(
            :get,
            uri.to_s,
            nil => :json))
      end

      define_method(:"#{plural}_from") do |path|
        uri = URI.parse(path)

        if uri.query
          uri.query += "&inline-relations-depth=1"
        else
          uri.query = "inline-relations-depth=1"
        end

        @base.request_path(
            :get,
            uri.to_s,
            nil => :json)[:resources].collect do |json|
          send(:"make_#{singular}", json)
        end
      end

      define_method(:"make_#{singular}") do |json|
        CFoundry::V2.const_get(klass).new(json[:metadata][:guid], self, json)
      end
    end

    alias :spaces :app_spaces
    alias :space :app_space
  end
end
