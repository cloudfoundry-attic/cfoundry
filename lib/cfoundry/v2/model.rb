module CFoundry::V2
  class Model
    class << self
      def defaults
        @defaults ||= {}
      end

      def attribute(name, opts = {})
        default = opts[:default] || nil
        defaults[name] = default if default

        define_method(name) {
          manifest[:entity][name] || default
        }

        define_method(:"#{name}=") { |val|
          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][name] = val
          @diff[name] = val
        }
      end

      def to_one(name, opts = {})
        obj = opts[:as] || name

        define_method(name) {
          if manifest[:entity].key? name
            @client.send(:"make_#{obj}", manifest[:entity][name])
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
          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][:"#{name}_guid"] =
            @diff[:"#{name}_guid"] = x.guid
        }
      end

      def to_many(plural, opts = {})
        singular = plural.to_s.sub(/s$/, "").to_sym

        object = opts[:as] || singular
        plural_object = :"#{object}s"

        define_method(plural) { |*args|
          depth, query = args

          if manifest[:entity].key?(plural)
            objs = manifest[:entity][plural]

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
              send("#{plural}_url"),
              depth || opts[:depth],
              query)
          end
        }

        define_method(:"#{plural}_url") {
          manifest[:entity][:"#{plural}_url"]
        }

        # TODO: these are hacky
        define_method(:"add_#{singular}") { |x|
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
      # inline depth of 2 for fewer requests
      @manifest ||= @client.base.send(object_name, @guid, 2)
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

    def create!
      @manifest =
        @client.base.send(
          :"create_#{object_name}",
          self.class.defaults.merge(@manifest[:entity]))

      @guid = @manifest[:metadata][:guid]

      true
    end

    def update!(diff = @diff)
      @client.base.send(:"update_#{object_name}", @guid, diff)

      @manifest = nil
    end

    def delete!
      @client.base.send(:"delete_#{object_name}", @guid)

      if @manifest
        @manifest.delete :metadata
      end
    end

    def exists?
      @client.base.send(object_name, @guid)
      true
    rescue CFoundry::APIError # TODO: NotFound would be better
      false
    end

    def ==(other)
      other.is_a?(self.class) && @guid == other.guid
    end
  end
end
