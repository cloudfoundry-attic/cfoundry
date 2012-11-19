require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceBinding < Model
    to_one    :app
    to_one    :service_instance

    queryable_by :app_guid, :service_instance_guid
  end
end
