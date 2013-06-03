class TestModel < CFoundry::V2::Model
end

class TestModelBuilder
  def self.build(guid, client, manifest=nil, &init)
    klass = TestModel.new(guid, client, manifest)
    klass.class_eval(&init) if init
    klass
  end
end