FactoryGirl.define do
  factory :user, :class => CFoundry::V2::User do
    guid { FactoryGirl.generate(:guid) }
    admin false

    initialize_with do
      CFoundry::V2::User.new(nil, nil)
    end
  end
end
