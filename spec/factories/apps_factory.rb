FactoryGirl.define do
  factory :app, :class => CFoundry::V2::App do
    sequence(:guid) { |n| "app-guid-#{n}" }
    ignore do
      manifest { {} }
      client { FactoryGirl.build(:client) }
    end

    initialize_with { new(guid, client, manifest) }
  end
end