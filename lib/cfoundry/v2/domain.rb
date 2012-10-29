require "cfoundry/v2/model"

module CFoundry::V2
  class Domain < Model
    attribute :name, :string
    attribute :wildcard, :boolean, :default => true
    to_one    :owning_organization, :as => :organization

    scoped_to_organization :owning_organization
  end
end
