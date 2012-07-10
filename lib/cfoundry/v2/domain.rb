require "cfoundry/v2/model"

module CFoundry::V2
  class Domain < Model
    attribute :name
    to_one    :organization
  end
end
