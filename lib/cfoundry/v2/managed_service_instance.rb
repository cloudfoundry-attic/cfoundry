require "cfoundry/v2/service_instance"

module CFoundry::V2
  class ManagedServiceInstance < ServiceInstance
    attribute :credentials, :hash
    to_one    :service_plan

    def self.object_name
      'service_instance'
    end
  end
end
