require "cfoundry/v2/model"

module CFoundry::V2
  class ServicePlan < Model
    attribute :name, :string
    attribute :description, :string
    attribute :unique_id, String
    attribute :free, :boolean, :default => false
    attribute :extra, :string
    attribute :public, :boolean
    to_one    :service
    to_many   :service_instances

    queryable_by :service_guid, :service_instance_guid
  end
end
