require "cfoundry/v2/model"

module CFoundry::V2
  class AppUsageEvent < Model
    attribute :state, :string
    attribute :memory_in_mb_per_instance, :integer
    attribute :instance_count, :integer
    attribute :app_guid, :string
    attribute :app_name, :string
    attribute :space_guid, :string
    attribute :space_name, :string
    attribute :org_guid, :string
  end
end
