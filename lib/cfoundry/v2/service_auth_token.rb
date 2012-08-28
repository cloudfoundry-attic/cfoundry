require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceAuthToken < Model
    attribute :label, :string
    attribute :provider, :string
    attribute :token, :string
  end
end
