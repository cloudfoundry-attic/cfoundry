module CFoundry::V2::ModelMagic
  module ToOne
    def to_one(name, opts = {})
      to_one_relations[name] = opts

      association_name = opts[:as] || name
      default = opts[:default]

      if has_default = opts.key?(:default)
        defaults[:"#{name}_guid"] = default
      end

      #
      # def MODEL
      #
      define_method(name) do
        return @cache[name] if @cache.key?(name)
        return @client.send(association_name) unless persisted?

        @cache[name] =
          if @manifest && @manifest[:entity].key?(name)
            @client.send(:"make_#{association_name}", @manifest[:entity][name])
          elsif url = send("#{name}_url")
            @client.send(:"#{association_name}_from", url)
          else
            default
          end
      end

      #
      # def create_MODEL
      #
      define_method("create_#{name}") do |*args|
        associated_instance = @client.send(:"#{association_name}")
        args.first.each do |name, value|
          associated_instance.send("#{name}=", value)
        end if args.first.is_a? Hash

        associated_instance.create!
        self.send("#{name}=", associated_instance)
      end

      #
      # def MODEL_url
      #
      define_method(:"#{name}_url") do
        manifest[:entity][:"#{name}_url"]
      end

      #
      # def MODEL=
      #
      define_method(:"#{name}=") do |assigned_value|
        klass = self.class.objects[association_name]

        unless has_default && assigned_value == default
          CFoundry::Validator.validate_type(assigned_value, klass)
        end

        @manifest ||= {}
        @manifest[:entity] ||= {}

        old_guid = @manifest[:entity][:"#{name}_guid"]
        association_guid = assigned_value ? assigned_value.guid : nil

        if old_guid != (association_guid)
          old_obj =
            @cache[name] || klass.new(@client, old_guid, @manifest[:entity][name])

          @changes[name] = [old_obj, assigned_value]
        end

        @cache[name] = assigned_value

        @manifest[:entity][:"#{name}_guid"] = association_guid
        @diff[:"#{name}_guid"] = association_guid
        assigned_value
      end
    end
  end
end
