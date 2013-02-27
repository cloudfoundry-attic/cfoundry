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
      # There is a difference between ruby 1.8.7 and 1.8.8 in the order that
      # the inherited callback gets called. In 1.8.7 the inherited callback
      # is called after the block; in 1.8.8 and later it's called before.
      # The upshot for us is we need a failproof way of getting the name
      # to klass. So we're using a global variable to hand off the value.
      # Please don't shoot us. - ESH & MMB
      $object_name = name
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
      fakes = default_fakes

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

      # make sure that the attributes provided are set after the defaults
      #
      # we have to do this for cases like environment_json vs. env,
      # where one would clobber the other
      attributes.each do |k, _|
        fakes.delete k
      end

      fakes = fakes.to_a
      fakes += attributes.to_a

      fakes
    end

    # override this to provide basic attributes (like name) dynamically
    def default_fakes
      self.class.defaults.merge(
        :guid => random_string("fake-#{object_name}-guid"))
    end

    def find_reverse_relationship(v)
      singular = object_name
      plural = plural_object_name

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
    def self.define_client_methods(&blk)
      FakeClient.module_eval(&blk)
    end

    def self.define_base_client_methods(&blk)
      FakeBase.module_eval(&blk)
    end
  end

end
