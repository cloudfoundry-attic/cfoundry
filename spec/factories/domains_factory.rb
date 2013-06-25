FactoryGirl.define do
  factory :domain, :class => CFoundry::V2::Domain do
    sequence(:guid) { |n| "domain-guid-#{n}" }
    ignore do
      client build(:client)
    end

    initialize_with { new(guid, client) }
  end
end
