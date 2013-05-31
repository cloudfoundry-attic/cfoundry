FactoryGirl.define do
  factory :user, :class => CFoundry::V2::User do
    sequence(:guid) { |n| "user-guid-#{n}" }
    ignore do
      client { FactoryGirl.build(:client) }
    end

    initialize_with { new(guid, client) }
  end
end