FactoryGirl.define do
  factory :organization, :class => CFoundry::V2::Organization do
    sequence(:guid) { |n| "organization-guid-#{n}" }

    initialize_with { new(guid, build(:client)) }
  end
end