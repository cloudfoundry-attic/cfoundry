require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceBinding < Model
    to_one    :app
    to_one    :service_instance
  end
end
