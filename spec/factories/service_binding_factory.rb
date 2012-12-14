FactoryGirl.define do
  factory :service_binding, :class => CFoundry::V2::ServiceBinding do
    guid { FactoryGirl.generate(:guid) }

    ignore do
      app nil
      service_instance nil
    end

    initialize_with do
      CFoundry::V2::ServiceBinding.new(nil, nil)
    end

    after_build do |app, evaluator|
      %w{app service_instance}.each do |attr|
        RR.stub(app).__send__(attr) { evaluator.send(attr) }
      end
    end
  end
end
