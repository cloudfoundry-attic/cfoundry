require "multi_json"
require "cfoundry/v2/model_magic"

module CFoundry::V2
  class Model
    include ActiveModel::Validations

    @@objects = {}

    extend ModelMagic

    class << self
      def objects
        @@objects
      end

      def inherited(klass)
        @@objects[klass.object_name] = klass
        super
      end
    end

    attr_accessor :guid, :cache, :changes
    attr_reader :diff

    def initialize(guid, client, manifest = nil, partial = false)
      @guid = guid
      @client = client
      @manifest = manifest
      @partial = partial
      @cache = {}
      @diff = {}
      @changes = {}
    end

    def manifest
      @manifest ||= @client.base.send(object_name, @guid)
    end

    def partial?
      @partial
    end

    def changed?
      !@changes.empty?
    end

    def inspect
      "\#<#{self.class.name} '#@guid'>"
    end

    def object_name
      @object_name ||= self.class.object_name
    end

    def plural_object_name
      @plural_object_name ||= self.class.plural_object_name
    end

    def invalidate!
      @manifest = nil
      @partial = false
      @cache = {}
      @diff = {}
      @changes = {}
    end

    def create
      create!
      true
    rescue CFoundry::APIError => e
      if e.instance_of? CFoundry::APIError
        errors.add(:base, :cc_client)
      else
        errors.add(attribute_for_error(e), e.message)
      end
      false
    end

    def attribute_for_error(error)
      :base
    end

    # this does a bit of extra processing to allow for
    # `delete!' followed by `create!'
    def create!
      payload = {}

      @manifest ||= {}
      @manifest[:entity] ||= {}

      @manifest[:entity].each do |k, v|
        if v.is_a?(Hash) && v.key?(:metadata)
          # skip; there's a _guid attribute already
        elsif v.is_a?(Array) && !v.empty? && v.all? { |x|
          x.is_a?(Hash) && x.key?(:metadata)
        }
          singular = k.to_s.sub(/s$/, "")

          payload[:"#{singular}_guids"] = v.collect do |x|
            if x.is_a?(Hash) && x.key?(:metadata)
              x[:metadata][:guid]
            else
              x
            end
          end
        elsif k.to_s.end_with?("_url")
        else
          payload[k] = v
        end
      end

      @manifest = @client.base.post("v2", plural_object_name,
        :content => :json,
        :accept => :json,
        :payload => payload
      )

      @guid = @manifest[:metadata][:guid]

      @diff.clear

      true
    end

    def update!
      @client.base.put("v2", plural_object_name, guid,
        :content => :json,
        :accept => :json,
        :payload => @diff
      )

      @diff.clear

      true
    end

    def delete(options = {})
      delete!(options)
    rescue CFoundry::APIError => e
      if e.instance_of? CFoundry::APIError
        errors.add(:base, :cc_client)
      else
        errors.add(attribute_for_error(e), e.message)
      end
      false
    end

    def delete!(options = {})
      @client.base.delete("v2", plural_object_name, guid, :params => options)

      @deleted = true

      @diff.clear

      if @manifest
        @manifest.delete :metadata
      end

      true
    end

    def to_param
      persisted? ? @guid.to_s : nil
    end

    def to_key
      persisted? ? [@guid] : nil
    end

    def persisted?
      @guid && !@deleted
    end

    def exists?
      invalidate!
      manifest
      true
    rescue CFoundry::NotFound
      false
    end

    def query_target(klass)
      self
    end

    def eql?(other)
      other.is_a?(self.class) && @guid == other.guid
    end

    alias :== :eql?

    def hash
      @guid.hash
    end
  end
end
