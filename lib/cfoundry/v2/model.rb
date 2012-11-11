require "multi_json"

module CFoundry::V2
  class Model
    class << self
      attr_reader :scoped_organization, :scoped_space

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

      def attributes
        @attributes ||= {}
      end

      def to_one_relations
        @to_one_relations ||= {}
      end

      def to_many_relations
        @to_many_relations ||= {}
      end

      def attribute(name, type, opts = {})
        attributes[name] = opts

        default = opts[:default]

        if has_default = opts.key?(:default)
          defaults[name] = default
        end

        define_method(name) {
          return @cache[name] if @cache.key?(name)

          @cache[name] = manifest[:entity][name] || default
        }

        define_method(:"#{name}=") { |val|
          unless has_default && val == default
            Model.validate_type(val, type)
          end

          @cache[name] = val

          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][name] = val
          @diff[name] = val
        }
      end

      def scoped_to_organization(relation = :organization)
        @scoped_organization = relation
      end

      def scoped_to_space(relation = :space)
        @scoped_space = relation
      end

      def to_one(name, opts = {})
        to_one_relations[name] = opts

        obj = opts[:as] || name
        kls = obj.to_s.capitalize.gsub(/(.)_(.)/) do
          $1 + $2.upcase
        end

        default = opts[:default]

        if has_default = opts.key?(:default)
          defaults[:"#{name}_guid"] = default
        end

        define_method(name) {
          return @cache[name] if @cache.key?(name)

          @cache[name] =
            if @manifest && @manifest[:entity].key?(name)
              @client.send(:"make_#{obj}", @manifest[:entity][name])
            elsif url = send("#{name}_url")
              @client.send(:"#{obj}_from", url, opts[:depth] || 1)
            else
              default
            end
        }

        define_method(:"#{name}_url") {
          manifest[:entity][:"#{name}_url"]
        }

        define_method(:"#{name}=") { |x|
          unless has_default && x == default
            Model.validate_type(x, CFoundry::V2.const_get(kls))
          end

          @cache[name] = x

          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][:"#{name}_guid"] =
            @diff[:"#{name}_guid"] = x && x.guid
        }
      end

      def to_many(plural, opts = {})
        to_many_relations[plural] = opts

        singular = plural.to_s.sub(/s$/, "").to_sym

        object = opts[:as] || singular
        plural_object = :"#{object}s"

        kls = object.to_s.capitalize.gsub(/(.)_(.)/) do
          $1 + $2.upcase
        end

        define_method(plural) { |*args|
          depth, query = args

          if !depth && !query && cache = @cache[plural]
            return cache
          end

          if @manifest && @manifest[:entity].key?(plural) && !depth
            objs = @manifest[:entity][plural]

            if query
              find_by = query.keys.first
              find_val = query.values.first
              objs = objs.select { |o| o[:entity][find_by] == find_val }
            end

            res =
              objs.collect do |json|
                @client.send(:"make_#{object}", json)
              end
          else
            res =
              @client.send(
                :"#{plural_object}_from",
                "/v2/#{object_name}s/#@guid/#{plural}",
                depth || opts[:depth],
                query)
          end

          unless depth || query
            @cache[plural] = res
          end

          res
        }

        define_method(:"#{plural}_url") {
          manifest[:entity][:"#{plural}_url"]
        }

        define_method(:"add_#{singular}") { |x|
          Model.validate_type(x, CFoundry::V2.const_get(kls))

          if cache = @cache[plural]
            cache << x unless cache.include?(x)
          end

          @client.base.request_path(
            Net::HTTP::Put,
            ["v2", "#{object_name}s", @guid, plural, x.guid],
            :accept => :json)
        }

        define_method(:"remove_#{singular}") { |x|
          Model.validate_type(x, CFoundry::V2.const_get(kls))

          if cache = @cache[plural]
            cache.delete(x)
          end

          @client.base.request_path(
            Net::HTTP::Delete,
            ["v2", "#{object_name}s", @guid, plural, x.guid],
            :accept => :json)
        }

        define_method(:"#{plural}=") { |xs|
          Model.validate_type(xs, [CFoundry::V2.const_get(kls)])

          @cache[plural] = xs

          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][:"#{singular}_guids"] =
            @diff[:"#{singular}_guids"] = xs.collect(&:guid)
        }
      end

      def has_summary(actions = {})
        define_method(:summary) do
          @client.base.request_path(
            Net::HTTP::Get,
            ["v2", "#{object_name}s", @guid, "summary"],
            :accept => :json)
        end

        define_method(:summarize!) do |*args|
          body, _ = args

          body ||= summary

          body.each do |key, val|
            if act = actions[key]
              instance_exec(val, &act)

            elsif self.class.attributes[key]
              self.send(:"#{key}=", val)

            elsif self.class.to_many_relations[key]
              singular = key.to_s.sub(/s$/, "").to_sym

              vals = val.collect { |sub|
                obj = @client.send(singular, sub[:guid], true)
                obj.summarize! sub
                obj
              }

              self.send(:"#{key}=", vals)

            elsif self.class.to_one_relations[key]
              obj = @client.send(key, val[:guid], true)
              obj.summarize! val

              self.send(:"#{key}=", obj)
            end
          end

          nil
        end
      end
    end

    attr_accessor :guid, :cache

    def initialize(guid, client, manifest = nil, partial = false)
      @guid = guid
      @client = client
      @manifest = manifest
      @partial = partial
      @cache = {}
      @diff = {}
    end

    def manifest
      @manifest ||= @client.base.send(object_name, @guid)
    end

    def partial?
      @partial
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
      @partial = false
      @cache = {}
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

    def update!(diff = {})
      diff = @diff.merge(diff)

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
