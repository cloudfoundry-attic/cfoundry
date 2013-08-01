require "cfoundry/v2/service_instance"

module CFoundry::V2
  class UserProvidedServiceInstance < ServiceInstance
    attribute :credentials, :hash
  end
end
