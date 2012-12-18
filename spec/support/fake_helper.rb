module Fake
  module FakeMethods
    def fake_client(attributes = {})
      CFoundry::V2::FakeClient.new.fake(attributes)
    end

    def fake(what, attributes = {})
      fake_client.send(what).fake(attributes)
    end

    def fake_list(what, count, attributes = {})
      objs = []

      count.times do
        objs << fake(what, attributes)
      end

      objs
    end

    def fake_model(name = :my_fake_model, &init)
      klass = Class.new(CFoundry::V2::FakeModel) do
        self.object_name = name
      end

      klass.class_eval(&init) if init

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

  def self.define_many_association(target, plural)
    target.class_eval do
      define_method(plural) do |*args|
        options, _ = args
        options ||= {}

        vals = get_many(plural) || []

        if options[:query]
          by, val = options[:query]
          vals.select do |v|
            v.send(by) == val
          end
        else
          vals
        end
      end
    end
  end
end

module CFoundry::V2
  class Model
    include Fake

    attr_writer :client

    private

    def get_many(plural)
      @cache[plural]
    end

    def fake_attributes(attributes)
      fakes = default_fakes.merge(attributes)

      # default relationships to other fake objects
      self.class.to_one_relations.each do |name, opts|
        # remove _guid (not an actual attribute)
        fakes.delete :"#{name}_guid"
        next if fakes.key?(name)

        fakes[name] =
          if opts.key?(:default)
            opts[:default]
          else
            @client.send(opts[:as] || name).fake
          end
      end

      fakes
    end

    # override this to provide basic attributes (like name) dynamically
    def default_fakes
      self.class.defaults.merge(
        :guid => random_string("fake-#{object_name}-guid"))
    end

    def setup_reverse_relationship(v)
      if v.is_a?(Array)
        v.each do |x|
          setup_reverse_relationship(x)
        end

        return
      end

      return unless v.is_a?(Model)

      relation, type = find_reverse_relationship(v)

      v.client = @client

      if type == :one
        v.send(:"#{relation}=", self)
      elsif type == :many
        v.send(:"#{relation}=", v.send(relation) + [self])
      end
    end

    def find_reverse_relationship(v)
      singular = object_name
      plural = :"#{object_name}s"

      v.class.to_one_relations.each do |attr, opts|
        return [attr, :one] if attr == singular
        return [attr, :one] if opts[:as] == singular
      end

      v.class.to_many_relations.each do |attr, opts|
        return [attr, :many] if attr == plural
        return [attr, :many] if opts[:as] == singular
      end
    end
  end


  class FakeBase < Base
  end


  class FakeClient < Client
    include Fake

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


  class FakeModel < CFoundry::V2::Model
    attr_reader :diff

    class << self
      attr_writer :object_name
    end
  end


  module ModelMagic
    def self.define_client_methods(&blk)
      FakeClient.module_eval(&blk)
    end

    def self.define_base_client_methods(&blk)
      FakeBase.module_eval(&blk)
    end
  end


  Model.objects.each_value do |klass|
    klass.to_many_relations.each do |plural, _|
      Fake.define_many_association(klass, plural)
    end

    FakeClient.class_eval do
      plural = :"#{klass.object_name}s"

      attr_writer plural
      Fake.define_many_association(self, plural)
    end
  end
end
