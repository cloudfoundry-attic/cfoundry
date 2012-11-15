require "cfoundry/v1/base"
require "cfoundry/v1/app"
require "cfoundry/v1/service"
require "cfoundry/v1/service_instance"
require "cfoundry/v1/user"


module CFoundry::V1
  # The primary API entrypoint. Wraps a BaseClient to provide nicer return
  # values. Initialize with the target and, optionally, an auth token. These
  # are the only two internal states.
  class Client
    attr_reader :base

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
      if user = info[:user]
        user(user)
      end
    end

    def current_space
      nil
    end

    def current_organization
      nil
    end


    # Retrieve target metadata.
    def info
      @base.info
    end

    # Retrieve available services.
    def services(depth = 0, query = {})
      services = []

      @base.system_services.each do |type, vendors|
        vendors.each do |vendor, providers|
          providers.each do |provider, versions|
            versions.each do |num, meta|
              services <<
                Service.new(vendor.to_s, num.to_s, meta[:description],
                            type, provider.to_s)
            end
          end
        end
      end

      services
    end

    # Retrieve available runtimes.
    def runtimes(depth = 1, query = {})
      runtimes = []

      @base.system_runtimes.each do |name, meta|
        runtimes <<
          Runtime.new(name.to_s, meta[:description], meta[:debug_modes],
            meta[:version], meta[:status], meta[:series], meta[:category])
      end

      runtimes
    end

    def runtime_by_name(name)
      runtimes.find { |r| r.name == name }
    end

    # Retrieve available frameworks.
    def frameworks(depth = 1, query = {})
      fs = info[:frameworks]
      return unless fs

      frameworks = []
      fs.each do |name, meta|
        runtimes = meta[:runtimes].collect do |r|
          Runtime.new(r[:name], r[:description], nil, r[:version],
            r[:status], r[:series], r[:category])
        end

        frameworks <<
          Framework.new(name.to_s, nil, runtimes, meta[:detection])
      end

      frameworks
    end

    def framework_by_name(name)
      frameworks.find { |f| f.name == name }
    end

    # Retrieve user list. Admin-only.
    def users(depth = 1, query = {})
      @base.users.collect do |json|
        User.new(
          json[:email],
          self,
          { :email => json[:email],
            :admin => json[:admin] })
      end
    end

    # Construct a User object. The return value is lazy, and no requests are
    # made from this alone.
    #
    # This should be used for both user creation (after calling User#create!)
    # and retrieval.
    def user(email)
      User.new(email, self)
    end

    # Create a user on the target and return a User object representing them.
    def register(email, password)
      @base.create_user(:email => email, :password => password)
      user(email)
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


    # Retreive all of the current user's applications.
    def apps(depth = 1, query = {})
      @base.apps.collect do |json|
        App.new(json[:name], self, json)
      end
    end

    # Construct an App object. The return value is lazy, and no requests are
    # made from this method alone.
    #
    # This should be used for both app creation (after calling App#create!)
    # and retrieval.
    def app(name = nil)
      App.new(name, self)
    end

    def app_by_name(name)
      app = app(name)
      app if app.exists?
    end

    # Retrieve all of the current user's services.
    def service_instances(depth = 1, query = {})
      @base.services.collect do |json|
        ServiceInstance.new(json[:name], self, json)
      end
    end

    # Construct a Service object. The return value is lazy, and no requests are
    # made from this method alone.
    #
    # This should be used for both service creation (after calling
    # Service#create!) and retrieval.
    def service_instance(name = nil)
      ServiceInstance.new(name, self)
    end

    def service_instance_by_name(name)
      service = service_instance(name)
      service if service.exists?
    end
  end
end
