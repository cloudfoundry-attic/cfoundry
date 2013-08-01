FactoryGirl.define do
  factory :service_instance, :class => CFoundry::V2::ManagedServiceInstance do
    sequence(:guid) { |n| "service-instance-guid-#{n}" }
    ignore do
      client { FactoryGirl.build(:client) }
    end

    initialize_with { new(guid, client) }
  end
end
