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
        }
      end

      def to_one(name, opts = {})
        obj = opts[:as] || name

        define_method(name) {
          if manifest[:entity].key? name
            @client.send(:"make_#{obj}", manifest[:entity][name])
          else
            @client.send(:"#{name}_from", send("#{obj}_url"))
          end
        }

        define_method(:"#{name}_url") {
          manifest[:entity][:"#{name}_url"]
        }

        define_method(:"#{name}=") { |x|
          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][:"#{name}_guid"] = x.id
        }
      end

      def to_many(plural, opts = {})
        singular = plural.to_s.sub(/s$/, "").to_sym
        object = opts[:as] || singular

        define_method(plural) {
          if manifest[:entity].key? plural
            manifest[:entity][plural].collect do |json|
              @client.send(:"make_#{object}", json)
            end
          else
            @client.send(:"#{plural}_from", send("#{plural}_url"))
          end
        }

        define_method(:"#{plural}_url") {
          manifest[:entity][:"#{plural}_url"]
        }

        # TODO: these are hacky
        define_method(:"add_#{singular}") { |x|
          @client.base.request_path(
            :put,
            ["v2", "#{object_name}s", @id, plural, x.id],
            nil => :json)
        }

        define_method(:"remove_#{singular}") {
          @client.base.request_path(
            :delete,
            ["v2", "#{object_name}s", @id, plural, x.id],
            nil => :json)
        }

        define_method(:"#{plural}=") { |xs|
          @manifest ||= {}
          @manifest[:entity] ||= {}
          @manifest[:entity][:"#{singular}_guids"] = xs.collect(&:id)
        }
      end
    end

    attr_reader :id

    def initialize(id, client, manifest = nil)
      @id = id
      @client = client
      @manifest = manifest
    end

    def manifest
      # inline depth of 2 for fewer requests
      @manifest ||= @client.base.send(object_name, @id, 2)
    end

    def inspect
      "\#<#{self.class.name} '#@id'>"
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
          @manifest[:entity].merge(self.class.defaults))

      @id = @manifest[:metadata][:guid]

      true
    end

    def update!(diff = nil)
      @client.base.send(
        :"update_#{object_name}",
        @id,
        diff || manifest[:entity])

      @manifest = nil
    end

    def delete!
      @client.base.send(:"delete_#{object_name}", @id)

      if @manifest
        @manifest.delete :metadata
      end
    end

    def exists?
      @client.base.send(object_name, @id)
      true
    rescue CFoundry::APIError # TODO: NotFound would be better
      false
    end

    def ==(other)
      other.is_a?(self.class) && @id == other.id
    end
  end
end
