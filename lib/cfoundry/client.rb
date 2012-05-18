require "cfoundry/restclient"
require "cfoundry/app"
require "cfoundry/service"
require "cfoundry/user"


module CFoundry
  class Client
    attr_reader :rest

    def initialize(*args)
      @rest = RESTClient.new(*args)
    end

    def target
      @rest.target
    end

    def proxy
      @rest.proxy
    end

    def proxy=(x)
      @rest.proxy = x
    end

    def trace
      @rest.trace
    end

    def trace=(x)
      @rest.trace = x
    end


    # Cloud metadata
    def info
      @rest.info
    end

    def system_services
      @rest.system_services
    end

    def system_runtimes
      @rest.system_runtimes
    end

    # Users
    def users
      @rest.users.collect do |json|
        CFoundry::User.new(
          json["email"],
          self,
          { "email" => json["email"],
            "admin" => json["admin"] })
      end
    end

    def user(email)
      CFoundry::User.new(email, self)
    end

    def register(email, password)
      @rest.create_user(:email => email, :password => password)
      user(email)
    end

    def login(email, password)
      @rest.token =
        @rest.create_token({ :password => password }, email)["token"]
    end

    def logout
      @rest.token = nil
    end

    def logged_in?
      !!@rest.token
    end


    # Applications
    def apps
      @rest.apps.collect do |json|
        CFoundry::App.new(json["name"], self, json)
      end
    end

    def app(name)
      CFoundry::App.new(name, self)
    end

    # Services
    def services
      @rest.services.collect do |json|
        CFoundry::Service.new(json["name"], self, json)
      end
    end

    def service(name)
      CFoundry::Service.new(name, self)
    end
  end
end
