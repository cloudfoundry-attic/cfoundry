FactoryGirl.define do
  factory :service_instance, :class => CFoundry::V2::ServiceInstance do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }

    ignore do
      service_bindings []
    end

    initialize_with do
      CFoundry::V2::ServiceInstance.new(nil, nil)
    end

    after_build do |svc, evaluator|
      %w{name service_bindings}.each do |attr|
        RR.stub(svc).__send__(attr) { evaluator.send(attr) }
      end
    end
  end
end
