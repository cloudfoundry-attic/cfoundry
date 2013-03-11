module V1Fake
  module FakeMethods
    def v1_fake_client(attributes = {})
      CFoundry::V1::FakeClient.new.fake(attributes)
    end

    def v1_fake(what, attributes = {})
      v1_fake_client.send(what).fake(attributes)
    end

    def v1_fake_list(what, count, attributes = {})
      objs = []

      count.times do
        objs << fake(what, attributes)
      end

      objs
    end

    def v1_fake_model(name = :my_fake_model, &init)
      # There is a difference between ruby 1.8.7 and 1.8.8 in the order that
      # the inherited callback gets called. In 1.8.7 the inherited callback
      # is called after the block; in 1.8.8 and later it's called before.
      # The upshot for us is we need a failproof way of getting the name
      # to klass. So we're using a global variable to hand off the value.
      # Please don't shoot us. - ESH & MMB
      $object_name = name
      klass = Class.new(CFoundry::V1::FakeModel) do
        self.object_name = name
      end

      klass.class_eval(&init) if init

      klass.define_client_methods

      klass
    end
  end

  def fake(attributes = {})
    fake_attributes(attributes).each do |k, v|
      send(:"#{k}=", v)
      setup_reverse_relationship(v)
    end

    self
  end

  def setup_reverse_relationship(v)
    # assign relationship for 'v' pointing back to this object
  end
end

module CFoundry::V1
  class Model
    include V1Fake

    attr_writer :client

    private

    def get_many(plural)
      @cache[plural]
    end

    def fake_attributes(attributes)
      default_fakes.merge(attributes)
    end

    # override this to provide basic attributes (like name) dynamically
    def default_fakes
      {}
    end
  end


  class FakeBase < Base
  end


  class FakeClient < Client
    include V1Fake

    def initialize(target = "http://example.com", token = nil)
      @base = FakeBase.new(target, token)
    end

    private

    def get_many(plural)
      instance_variable_get(:"@#{plural}")
    end

    def fake_attributes(attributes)
      attributes
    end

    def setup_reverse_relationship(v)
      if v.is_a?(Model)
        v.client = self
      elsif v.is_a?(Array)
        v.each do |x|
          setup_reverse_relationship(x)
        end
      end
    end
  end


  class FakeModel < CFoundry::V1::Model
    attr_reader :diff

    def self.inherited(klass)
      class << klass
        attr_writer :object_name
      end

      # There is a difference between ruby 1.8.7 and 1.8.8 in the order that
      # the inherited callback gets called. In 1.8.7 the inherited callback
      # is called after the block; in 1.8.8 and later it's called before.
      # The upshot for us is we need a failproof way of getting the name
      # to klass. So we're using a global variable to hand off the value.
      # Please don't shoot us. - ESH & MMB
      klass.object_name = $object_name
      super
    end

    class << self
      attr_writer :object_name
    end
  end


  module ModelMagic
    def self.on_client(&blk)
      FakeClient.module_eval(&blk)
    end

    def self.on_base_client(&blk)
      FakeBase.module_eval(&blk)
    end
  end
end
