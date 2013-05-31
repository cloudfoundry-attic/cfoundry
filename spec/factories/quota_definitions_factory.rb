FactoryGirl.define do
  factory :quota_definition, :class => CFoundry::V2::QuotaDefinition do
    sequence(:name) { |n| "quota-definition-name-#{n}" }
    sequence(:guid) { |n| "quota-definition-guid-#{n}" }

    initialize_with { new(guid, build(:client)) }
  end
end