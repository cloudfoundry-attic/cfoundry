FactoryGirl.define do
  factory :domain, :class => CFoundry::V2::Domain do
    sequence(:guid) { |n| "domain-guid-#{n}" }

    initialize_with { new(guid, build(:client)) }
  end
end
