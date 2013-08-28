FactoryGirl.define do
  factory :service, :class => CFoundry::V2::Service do
    sequence(:guid) { |n| "service-guid-#{n}" }
    ignore do
      client { FactoryGirl.build(:client) }
    end

    initialize_with { new(guid, client) }
  end
end
