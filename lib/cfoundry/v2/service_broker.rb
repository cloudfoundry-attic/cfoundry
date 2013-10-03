require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceBroker < Model
    attribute :name, :string
    attribute :broker_url, :string
    attribute :auth_username, :string
    attribute :auth_password, :string

    queryable_by :name
  end
end
