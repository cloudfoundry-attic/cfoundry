require "cfoundry/v2/model"

module CFoundry::V2
  class ServicePlan < Model
    attribute :name, :string
    attribute :description, :string
    to_one    :service
    to_many   :service_instances

    queryable_by :service_guid, :service_instance_guid
  end
end
