require "multi_json"

module CFoundry::V2
  class Model
    class << self
      def value_matches?(val, type)
        case type
        when Class
          val.is_a?(type)
        when Regexp
          val.is_a?(String) && val =~ type
        when :url
          value_matches?(val, URI::regexp(%w(http https)))
        when :https_url
          value_matches?(val, URI::regexp("https"))
        when :boolean
          val.is_a?(TrueClass) || val.is_a?(FalseClass)
        when Array
          val.all? do |x|
            value_matches?(x, type.first)
          end
        when Hash
          val.is_a?(Hash) &&
            type.all? { |name, subtype|
              val.key?(name) && value_matches?(val[name], subtype)
            }
        else
          val.is_a?(Object.const_get(type.to_s.capitalize))
        end
      end

      def validate_type(val, type)
        unless value_matches?(val, type)
          raise "invalid attribute; expected #{type.inspect} but got #{val.inspect}"
        end
      end

      def defaults
        @defaults ||= {}
      end

      def attribute(name, type, opts = {})
        default = opts[:default] || nil

        has_default = opts.key?(:default)
        defaults[name] = default if has_default

        define_method(name) {
          manifest[:entity][name] || default
        }

        define_method(:"#{name}=") { |val|
          unless has_default && val == default
            Model.validate_type(val, type)
          end

          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][name] = val
          @diff[name] = val
        }
      end

      def to_one(name, opts = {})
        obj = opts[:as] || name
        kls = obj.to_s.capitalize

        define_method(name) {
          if @manifest && @manifest[:entity].key?(name)
            @client.send(:"make_#{obj}", @manifest[:entity][name])
          else
            @client.send(
              :"#{obj}_from",
              send("#{name}_url"),
              opts[:depth] || 1)
          end
        }

        define_method(:"#{name}_url") {
          manifest[:entity][:"#{name}_url"]
        }

        define_method(:"#{name}=") { |x|
          Model.validate_type(x, CFoundry::V2.const_get(kls))

          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][:"#{name}_guid"] =
            @diff[:"#{name}_guid"] = x.guid
        }
      end

      def to_many(plural, opts = {})
        singular = plural.to_s.sub(/s$/, "").to_sym
        kls = singular.to_s.capitalize

        object = opts[:as] || singular
        plural_object = :"#{object}s"

        define_method(plural) { |*args|
          depth, query = args

          if @manifest && @manifest[:entity].key?(plural) && !depth
            objs = @manifest[:entity][plural]

            if query
              find_by = query.keys.first
              find_val = query.values.first
              objs = objs.select { |o| o[:entity][find_by] == find_val }
            end

            objs.collect do |json|
              @client.send(:"make_#{object}", json)
            end
          else
            @client.send(
              :"#{plural_object}_from",
              "/v2/#{object_name}s/#@guid/#{plural}",
              depth || opts[:depth],
              query)
          end
        }

        define_method(:"#{plural}_url") {
          manifest[:entity][:"#{plural}_url"]
        }

        # TODO: these are hacky
        define_method(:"add_#{singular}") { |x|
          Model.validate_type(x, CFoundry::V2.const_get(kls))

          @client.base.request_path(
            :put,
            ["v2", "#{object_name}s", @guid, plural, x.guid],
            nil => :json)
        }

        define_method(:"remove_#{singular}") {
          @client.base.request_path(
            :delete,
            ["v2", "#{object_name}s", @guid, plural, x.guid],
            nil => :json)
        }

        define_method(:"#{plural}=") { |xs|
          Model.validate_type(x, [CFoundry::V2.const_get(kls)])

          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][:"#{singular}_guids"] =
            @diff[:"#{singular}_guids"] = xs.collect(&:guid)
        }
      end
    end

    attr_reader :guid

    def initialize(guid, client, manifest = nil)
      @guid = guid
      @client = client
      @manifest = manifest
      @diff = {}
    end

    def manifest
      @manifest ||= @client.base.send(object_name, @guid)
    end

    def inspect
      "\#<#{self.class.name} '#@guid'>"
    end

    def object_name
      @object_name ||=
        self.class.name.split("::").last.gsub(
          /([a-z])([A-Z])/,
          '\1_\2').downcase
    end

    def invalidate!
      @manifest = nil
      @diff = {}
    end

    # this does a bit of extra processing to allow for
    # `delete!' followed by `create!'
    def create!
      payload = {}

      self.class.defaults.merge(@manifest[:entity]).each do |k, v|
        if v.is_a?(Hash) && v.key?(:metadata)
          # skip; there's a _guid attribute already
        elsif v.is_a?(Array) && v.all? { |x|
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

    def update!(diff = @diff)
      @manifest = @client.base.send(:"update_#{object_name}", @guid, diff)

      @diff.clear if diff == @diff

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
      @client.base.send(object_name, @guid)
      true
    rescue CFoundry::APIError # TODO: NotFound would be better
      false
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
