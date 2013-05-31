FactoryGirl.define do
  factory :app_event, :class => CFoundry::V2::AppEvent do
    sequence(:guid) { |n| "app-event-guid-#{n}" }

    initialize_with { new(guid, build(:client)) }
  end
end