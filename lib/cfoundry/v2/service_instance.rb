require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceInstance < Model
    attribute :name, :string
    to_one    :space
    to_one    :service_plan
    to_many   :service_bindings

    scoped_to_space

    queryable_by :name, :space_guid, :service_plan_guid, :service_binding_guid
  end
end
