require "cfoundry/v2/model"

module CFoundry::V2
  class QuotaDefinition < Model
    attribute :name,                       :string
    attribute :non_basic_services_allowed, :boolean
    attribute :total_services,             :integer
    attribute :memory_limit,               :integer

    queryable_by :name
  end
end
