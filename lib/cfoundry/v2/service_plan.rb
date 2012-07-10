require "cfoundry/v2/model"

module CFoundry::V2
  class ServicePlan < Model
    attribute :name
    attribute :description
    to_one    :service
    to_many   :service_instances
  end
end
