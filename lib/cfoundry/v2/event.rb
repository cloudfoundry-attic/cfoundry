require "cfoundry/v2/model"

module CFoundry::V2
  class Event < Model
    attribute :actee, :string
    attribute :actee_type, :string
    attribute :actor, :string
    attribute :actor_type, :string
    attribute :organization_guid, :string
    attribute :space_guid, :string
    attribute :timestamp, :string
    attribute :type, :string
    attribute :metadata, Hash

    queryable_by :type, :timestamp
  end
end
