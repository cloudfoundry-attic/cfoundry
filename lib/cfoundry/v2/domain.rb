require "cfoundry/v2/model"

module CFoundry::V2
  class Domain < Model
    attribute :name, :string
    attribute :wildcard, :boolean
    to_one    :owning_organization, :as => :organization, :default => nil

    queryable_by :name, :owning_organization_guid, :space_guid
  end
end
