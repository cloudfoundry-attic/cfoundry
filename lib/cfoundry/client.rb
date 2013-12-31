require "cfoundry/concerns/proxy_options"

require "cfoundry/baseclient"
require "cfoundry/rest_client"
require "cfoundry/auth_token"

require "cfoundry/v2/app"
require "cfoundry/v2/app_instance"
require "cfoundry/v2/service"
require "cfoundry/v2/service_binding"
require "cfoundry/v2/managed_service_instance"
require "cfoundry/v2/user_provided_service_instance"
require "cfoundry/v2/service_plan"
require "cfoundry/v2/service_auth_token"
require "cfoundry/v2/user"
require "cfoundry/v2/organization"
require "cfoundry/v2/space"
require "cfoundry/v2/domain"
require "cfoundry/v2/route"
require "cfoundry/v2/stack"
require "cfoundry/v2/quota_definition"
require "cfoundry/v2/app_event"
require "cfoundry/v2/app_usage_event"
require "cfoundry/v2/event"
require "cfoundry/v2/service_broker"

require "cfoundry/v2/base"
require "cfoundry/v2/client"
#require "cfoundry/v2/fake_client"

module CFoundry
  class Client < BaseClient
    def self.new(*args)
      warn "DEPRECATION WARNING: Please use CFoundry::Client.get instead of CFoundry::Client.new"
      get(*args)
    end

    def self.get(*args)
      CFoundry::V2::Client.new(*args).tap { |client| client.info }
    end
  end
end
