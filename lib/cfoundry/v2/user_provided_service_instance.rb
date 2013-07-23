require "cfoundry/v2/model"

module CFoundry::V2
  class UserProvidedServiceInstance < Model
    attribute :name, :string
    attribute :credentials, :hash
    to_one    :space

    scoped_to_space
  end
end
