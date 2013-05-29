module CFoundry::V2::ModelMagic
  module ToMany
    def to_many(plural, opts = {})
      to_many_relations[plural] = opts

      singular = plural.to_s.sub(/s$/, "").to_sym

      include ::CFoundry::V2::QUERIES[singular]

      object = opts[:as] || singular

      kls = object.to_s.camelcase

      #
      # def MODELs
      #
      define_method(plural) do |*args|
        klass = CFoundry::V2.const_get(kls)

        opts, _ = args
        opts ||= {}

        if opts.empty? && cache = @cache[plural]
          return cache
        end

        if @manifest && @manifest[:entity].key?(plural) && opts.empty?
          objs = @manifest[:entity][plural]

          if query = opts[:query]
            find_by, find_val = query
            objs = objs.select { |o| o[:entity][find_by] == find_val }
          end

          res =
            objs.collect do |json|
              @client.send(:"make_#{object}", json)
            end
        else
          res =
            @client.send(
              :"#{klass.plural_object_name}_from",
              "/v2/#{plural_object_name}/#@guid/#{plural}",
              opts)
        end

        if opts.empty?
          @cache[plural] = res
        end

        res
      end

      #
      # def MODELs_url
      #
      define_method(:"#{plural}_url") do
        manifest[:entity][:"#{plural}_url"]
      end

      #
      # def add_MODEL
      #
      define_method(:"add_#{singular}") do |x|
        klass = self.class.objects[object]

        CFoundry::Validator.validate_type(x, klass)

        if cache = @cache[plural]
          cache << x unless cache.include?(x)
        end

        @client.base.put("v2", plural_object_name, @guid, plural, x.guid, :accept => :json)
      end

      #
      # def create_MODEL
      #
      define_method("create_#{singular}") do |*args|
        associated_instance = @client.send(:"#{singular}")
        args.first.each do |name, value|
          associated_instance.send("#{name}=", value)
        end if args.first.is_a? Hash

        associated_instance.create!
        self.send(:"add_#{singular}", associated_instance)
        associated_instance
      end

      #
      # def remove_MODEL
      #
      define_method(:"remove_#{singular}") do |x|
        klass = self.class.objects[object]

        CFoundry::Validator.validate_type(x, klass)

        if cache = @cache[plural]
          cache.delete(x)
        end

        @client.base.delete("v2", plural_object_name, @guid, plural, x.guid, :accept => :json)
      end

      #
      # def MODELs=
      #
      define_method(:"#{plural}=") do |xs|
        klass = self.class.objects[object]

        CFoundry::Validator.validate_type(xs, [klass])

        @manifest ||= {}
        @manifest[:entity] ||= {}

        old = @manifest[:entity][:"#{singular}_guids"]
        if old != xs.collect(&:guid)
          old_objs =
            @cache[plural] ||
              if all = @manifest[:entity][plural]
                all.collect do |m|
                  klass.new(@client, m[:metadata][:guid], m)
                end
              elsif old
                old.collect { |id| klass.new(@client, id) }
              end

          @changes[plural] = [old_objs, xs]
        end

        @cache[plural] = xs

        @manifest[:entity][:"#{singular}_guids"] =
          @diff[:"#{singular}_guids"] = xs.collect(&:guid)
      end
    end
  end
end
