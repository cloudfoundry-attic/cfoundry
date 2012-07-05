require "cfoundry/restclient"
require "cfoundry/app"
require "cfoundry/service"
require "cfoundry/user"


module CFoundry
  # The primary API entrypoint. Wraps RESTClient to provide nicer return
  # values. Initialize with the target and, optionally, an auth token. These
  # are the only two internal states.
  class Client
    # Internal RESTClient instance. Normally won't be touching this.
    attr_reader :rest

    # Create a new Client for interfacing with the given target.
    #
    # A token may also be provided to skip the login step.
    def initialize(target = "http://api.cloudfoundry.com", token = nil)
      @rest = RESTClient.new(target, token)
    end

    # The current target URL of the client.
    def target
      @rest.target
    end

    # Current proxy user. Usually nil.
    def proxy
      @rest.proxy
    end

    # Set the proxy user for the client. Must be authorized as an
    # administrator for this to have any effect.
    def proxy=(email)
      @rest.proxy = email
    end

    # Is the client tracing API requests?
    def trace
      @rest.trace
    end

    # Set the tracing flag; if true, API requests and responses will be
    # printed out.
    def trace=(bool)
      @rest.trace = bool
    end


    # Retrieve target metadata.
    def info
      @rest.info
    end

    # Retrieve available services. Returned as a Hash from vendor => metadata.
    def system_services
      services = {}

      @rest.system_services.each do |type, vendors|
        vendors.each do |vendor, versions|
          services[vendor] =
            { :type => type,
              :versions => versions.keys,
              :description => versions.values[0][:description],
              :vendor => vendor
            }
        end
      end

      services
    end

    # Retrieve available runtimes.
    def system_runtimes
      @rest.system_runtimes
    end


    # Retrieve user list. Admin-only.
    def users
      @rest.users.collect do |json|
        CFoundry::User.new(
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
      CFoundry::User.new(email, self)
    end

    # Create a user on the target and return a User object representing them.
    def register(email, password)
      @rest.create_user(:email => email, :password => password)
      user(email)
    end

    # Authenticate with the target. Sets the client token.
    def login(email, password)
      @rest.token =
        @rest.create_token({ :password => password }, email)[:token]
    end

    # Clear client token. No requests are made for this.
    def logout
      @rest.token = nil
    end

    # Is an authentication token set on the client?
    def logged_in?
      !!@rest.token
    end


    # Retreive all of the current user's applications.
    def apps
      @rest.apps.collect do |json|
        CFoundry::App.new(json[:name], self, json)
      end
    end

    # Construct an App object. The return value is lazy, and no requests are
    # made from this method alone.
    #
    # This should be used for both app creation (after calling App#create!)
    # and retrieval.
    def app(name)
      CFoundry::App.new(name, self)
    end


    # Retrieve all of the current user's services.
    def services
      @rest.services.collect do |json|
        CFoundry::Service.new(json[:name], self, json)
      end
    end

    # Construct a Service object. The return value is lazy, and no requests are
    # made from this method alone.
    #
    # This should be used for both service creation (after calling
    # Service#create!) and retrieval.
    def service(name)
      CFoundry::Service.new(name, self)
    end
  end
end
