require "multi_json"

require "cfoundry/v1/model_magic"


module CFoundry::V1
  class Model
    @@objects = {}

    extend ModelMagic

    class << self
      attr_writer :object_name, :base_object_name

      def object_name
        @object_name ||=
          name.split("::").last.gsub(
            /([a-z])([A-Z])/,
            '\1_\2').downcase.to_sym
      end

      def base_object_name
        @base_object_name ||= object_name
      end

      def plural_object_name
        "#{object_name}s"
      end

      def plural_base_object_name
        "#{base_object_name}s"
      end

      def objects
        @@objects
      end

      def inherited(klass)
        @@objects[klass.object_name] = klass
        super
      end
    end

    attr_accessor :guid, :changes

    def initialize(guid, client, manifest = nil)
      @guid = guid
      @client = client
      @manifest = manifest
      @changes = {}
    end

    def manifest
      @manifest ||= @client.base.send(base_object_name, @guid)
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

    def base_object_name
      @base_object_name ||= self.class.base_object_name
    end

    def guid_name
      self.class.guid_name
    end

    def invalidate!
      @manifest = nil
      @changes = {}
    end

    def create!
      @manifest = @client.base.send(:"create_#{base_object_name}", write_manifest)

      @guid = read_manifest[guid_name]

      true
    end

    def update!
      @client.base.send(:"update_#{base_object_name}", @guid, write_manifest)

      true
    end

    def delete!
      @client.base.send(:"delete_#{base_object_name}", @guid)

      @guid = nil

      true
    end

    def exists?
      invalidate!
      manifest
      true
    rescue CFoundry::NotFound
      false
    end

    def read_manifest
      read = {}

      self.class.read_locations.each do |name, where|
        found, val = find_path(manifest, where)
        read[name] = val if found
      end

      self.class.write_locations.each do |name, where|
        next if self.class.read_only_attributes.include? name

        found, val = find_path(manifest, where)
        read[name] = val if found
      end

      read[guid_name] = @guid

      read
    end

    def find_path(hash, path)
      return [false, nil] unless hash

      first, *rest = path
      return [false, nil] unless hash.key?(first)

      here = hash[first]

      if rest.empty?
        [true, here]
      else
        find_path(here, rest)
      end
    end

    def write_manifest(body = read_manifest, onto = {})
      onto[guid_name] = @guid if guid_name

      self.class.write_locations.each do |name, where|
        next if self.class.read_only_attributes.include? name
        put(body[name], onto, where) if body.key?(name)
      end

      onto
    end

    def put(what, where, path)
      if path.size == 1
        where[path.last] = what
      elsif name = path.first
        where[name] ||= {}
        put(what, where[name], path[1..-1])
      end

      nil
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
