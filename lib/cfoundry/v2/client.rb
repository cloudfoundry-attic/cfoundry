require "multi_json"
require "base64"

require "cfoundry/v2/base"

require "cfoundry/v2/app"
require "cfoundry/v2/framework"
require "cfoundry/v2/organization"
require "cfoundry/v2/runtime"
require "cfoundry/v2/service"
require "cfoundry/v2/service_binding"
require "cfoundry/v2/service_instance"
require "cfoundry/v2/service_plan"
require "cfoundry/v2/service_auth_token"
require "cfoundry/v2/space"
require "cfoundry/v2/user"
require "cfoundry/v2/domain"
require "cfoundry/v2/route"

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
      if guid = @base.token_data[:user_id]
        user = user(guid)
        user.emails = [{ :value => @base.token_data[:email] }]
        user
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


    [ :app, :organization, :space, :user, :runtime, :framework, :service,
      :domain, :route, :service_plan, :service_binding, :service_instance,
      :service_auth_token
    ].each do |singular|
      plural = :"#{singular}s"

      classname = singular.to_s.capitalize.gsub(/(.)_(.)/) do
        $1 + $2.upcase
      end

      klass = CFoundry::V2.const_get(classname)

      scoped_organization = klass.scoped_organization
      scoped_space = klass.scoped_space

      has_name = klass.method_defined? :name

      define_method(singular) do |*args|
        guid, _ = args

        x = klass.new(guid, self)

        # when creating an object, automatically set the org/space
        unless guid
          if scoped_organization && current_organization
            x.send(:"#{scoped_organization}=", current_organization)
          end

          if scoped_space && current_space
            x.send(:"#{scoped_space}=", current_space)
          end
        end

        x
      end

      define_method(plural) do |*args|
        depth, query = args
        depth ||= 1

        # use current org/space
        if scoped_space && current_space
          query ||= {}
          query[:"#{scoped_space}_guid"] ||= current_space.guid
        elsif scoped_organization && current_organization
          query ||= {}
          query[:"#{scoped_organization}_guid"] ||= current_organization.guid
        end

        @base.send(plural, depth, query).collect do |json|
          send(:"make_#{singular}", json)
        end
      end

      if has_name
        define_method(:"#{singular}_by_name") do |name, *args|
          depth, _ = args
          depth ||= 1

          # use current org/space
          if scoped_space && current_space
            current_space.send(plural, depth, :name => name).first
          elsif scoped_organization && current_organization
            current_organization.send(plural, depth, :name => name).first
          else
            send(plural, depth, :name => name).first
          end
        end
      end

      define_method(:"#{singular}_from") do |path, *args|
        send(
          :"make_#{singular}",
          @base.request_path(
            Net::HTTP::Get,
            path,
            nil => :json,
            :params => @base.params_from(args)))
      end

      define_method(:"#{plural}_from") do |path, *args|
        params = @base.params_from(args)

        objs = @base.all_pages(
          params,
          @base.request_path(
            Net::HTTP::Get,
            path,
            nil => :json,
            :params => params))

        objs.collect do |json|
          send(:"make_#{singular}", json)
        end
      end

      define_method(:"make_#{singular}") do |json|
        klass.new(
          json[:metadata][:guid],
          self,
          json)
      end
    end
  end
end
