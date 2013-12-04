require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceInstance < Model
    attribute :name, :string
    attribute :dashboard_url, :string
    to_one    :space
    to_many   :service_bindings

    scoped_to_space

    queryable_by :name, :space_guid, :service_plan_guid, :service_binding_guid, :gateway_name
  end
end
