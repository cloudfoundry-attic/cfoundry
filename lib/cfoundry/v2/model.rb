require "multi_json"

require "cfoundry/v2/model_magic"


module CFoundry::V2
  class Model
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

    def invalidate!
      @manifest = nil
      @partial = false
      @cache = {}
      @diff = {}
      @changes = {}
    end

    # this does a bit of extra processing to allow for
    # `delete!' followed by `create!'
    def create!
      payload = {}

      @manifest ||= {}
      @manifest[:entity] ||= {}

      self.class.defaults.merge(@manifest[:entity]).each do |k, v|
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
        elsif k.to_s.end_with?("_json") && v.is_a?(String)
          payload[k] = MultiJson.load(v)
        elsif k.to_s.end_with?("_url")
        else
          payload[k] = v
        end
      end

      @manifest = @client.base.send(:"create_#{object_name}", payload)

      @guid = @manifest[:metadata][:guid]

      @diff.clear

      true
    end

    def update!
      @manifest = @client.base.send(:"update_#{object_name}", @guid, @diff)

      @diff.clear

      true
    end

    def delete!
      @client.base.send(:"delete_#{object_name}", @guid)

      @guid = nil

      @diff.clear

      if @manifest
        @manifest.delete :metadata
      end

      true
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
