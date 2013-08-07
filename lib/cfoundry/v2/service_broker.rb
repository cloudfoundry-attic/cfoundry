require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceBroker < Model
    attribute :name, :string
    attribute :broker_url, :string
    attribute :token, :string
  end
end
