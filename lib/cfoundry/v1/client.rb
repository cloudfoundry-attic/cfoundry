require File.expand_path("../../concerns/login_helpers", __FILE__)

module CFoundry::V1
  # The primary API entrypoint. Wraps a BaseClient to provide nicer return
  # values. Initialize with the target and, optionally, an auth token. These
  # are the only two internal states.
  class Client
    include ClientMethods, CFoundry::LoginHelpers

    attr_reader :base

    # Create a new Client for interfacing with the given target.
    #
    # A token may also be provided to skip the login step.
    def initialize(target = "http://api.cloudfoundry.com", token = nil)
      @base = Base.new(target, token)
    end

    def version
      1
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
    def services(options = {})
      services = []

      @base.system_services.each do |type, vendors|
        vendors.each do |vendor, providers|
          providers.each do |provider, properties|
            properties.each do |_, meta|
              meta[:supported_versions].each do |ver|
                state = meta[:version_aliases].find { |k, v| v == ver }

                services <<
                  Service.new(vendor.to_s, ver.to_s, meta[:description],
                              type.to_s, provider.to_s, state && state.first,
                              generate_plans(meta))
              end
            end
          end
        end
      end

      services
    end

    def generate_plans(meta)
      names = meta[:plans]
      descriptions = meta[:plan_descriptions]
      default_name = meta[:default_plan]
      names.map { |name|
        description = descriptions[name.to_sym] if descriptions
        is_default = name == default_name || names.length == 1
        ServicePlan.new(name, description, is_default)
      }
    end

    # Retrieve available runtimes.
    def runtimes(options = {})
      runtimes = []

      @base.system_runtimes.each do |name, meta|
        runtimes <<
          Runtime.new(name.to_s, meta[:version], meta[:debug_modes])
      end

      runtimes
    end

    def runtime(name)
      Runtime.new(name)
    end

    def runtime_by_name(name)
      runtimes.find { |r| r.name == name }
    end

    # Retrieve available frameworks.
    def frameworks(options = {})
      fs = info[:frameworks]
      return unless fs

      frameworks = []
      fs.each do |name, meta|
        runtimes = meta[:runtimes].collect do |r|
          Runtime.new(r[:name], r[:description])
        end

        frameworks <<
          Framework.new(name.to_s, nil, runtimes, meta[:detection])
      end

      frameworks
    end

    def framework(name)
      Framework.new(name)
    end

    def framework_by_name(name)
      frameworks.find { |f| f.name == name }
    end

    # Create a user on the target and return a User object representing them.
    def register(email, password)
      @base.create_user(:email => email, :password => password)
      user(email)
    end

    # Clear client token. No requests are made for this.
    def logout
      @base.token = nil
    end

    # Is an authentication token set on the client?
    def logged_in?
      !!@base.token
    end
  end
end
