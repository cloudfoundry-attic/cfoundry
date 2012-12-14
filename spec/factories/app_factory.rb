FactoryGirl.define do
  factory :app, :class => CFoundry::V2::App do
    guid { FactoryGirl.generate(:guid) }
    name { FactoryGirl.generate(:random_string) }
    memory 128
    total_instances 0
    production false
    state "STOPPED"

    ignore do
      routes []
      service_bindings []
    end

    initialize_with do
      CFoundry::V2::App.new(nil, nil)
    end

    after_build do |app, evaluator|
      %w{name routes service_bindings}.each do |attr|
        RR.stub(app).__send__(attr) { evaluator.send(attr) }
      end
    end
  end
end
