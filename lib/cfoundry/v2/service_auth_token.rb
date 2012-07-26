require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceAuthToken < Model
    attribute :label
    attribute :provider
    attribute :token
  end
end
