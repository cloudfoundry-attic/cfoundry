require "cfoundry/validator"

module CFoundry::V2
  # object name -> module containing query methods
  #
  # e.g. app -> { app_by_name, app_by_space_guid, ... }
  QUERIES = Hash.new do |h, k|
    h[k] = Module.new
  end

  module BaseClientMethods
  end

  module ClientMethods
  end

  module ModelMagic
    attr_reader :scoped_organization, :scoped_space

    def object_name
      @object_name ||=
        name.split("::").last.gsub(
          /([a-z])([A-Z])/,
          '\1_\2').downcase.to_sym
    end

    def plural_object_name
      :"#{object_name}s"
    end

    def define_client_methods(&blk)
      ClientMethods.module_eval(&blk)
    end

    def define_base_client_methods(&blk)
      BaseClientMethods.module_eval(&blk)
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

    def inherited(klass)
      singular = klass.object_name
      plural = klass.plural_object_name

      define_base_client_methods do
        define_method(singular) do |guid, *args|
          get("v2", plural, guid, :accept => :json,
              :params => ModelMagic.params_from(args))
        end

        define_method(:"create_#{singular}") do |payload|
          post(payload, "v2", plural, :content => :json, :accept => :json)
        end

        define_method(:"delete_#{singular}") do |guid|
          delete("v2", plural, guid)
          true
        end

        define_method(:"update_#{singular}") do |guid, payload|
          put(payload, "v2", plural, guid, :content => :json, :accept => :json)
        end

        define_method(plural) do |*args|
          all_pages(
            get("v2", plural, :accept => :json,
                :params => ModelMagic.params_from(args)))
        end
      end

      define_client_methods do
        define_method(singular) do |*args|
          guid, partial, _ = args

          x = klass.new(guid, self, nil, partial)

          # when creating an object, automatically set the org/space
          unless guid
            if klass.scoped_organization && current_organization
              x.send(:"#{klass.scoped_organization}=", current_organization)
            end

            if klass.scoped_space && current_space
              x.send(:"#{klass.scoped_space}=", current_space)
            end
          end

          x
        end

        define_method(plural) do |*args|
          # use current org/space
          if klass.scoped_space && current_space
            current_space.send(plural, *args)
          elsif klass.scoped_organization && current_organization
            current_organization.send(plural, *args)
          else
            @base.send(plural, *args).collect do |json|
              send(:"make_#{singular}", json)
            end
          end
        end

        define_method(:"#{singular}_from") do |path, *args|
          send(
            :"make_#{singular}",
            @base.request_path(
              Net::HTTP::Get,
              path,
              :accept => :json,
              :params => ModelMagic.params_from(args)))
        end

        define_method(:"#{plural}_from") do |path, *args|
          objs = @base.all_pages(
            @base.request_path(
              Net::HTTP::Get,
              path,
              :accept => :json,
              :params => ModelMagic.params_from(args)))

          objs.collect do |json|
            send(:"make_#{singular}", json)
          end
        end

        define_method(:"make_#{singular}") do |json|
          klass.new(
            json[:metadata][:guid],
            self,
            json)
        end
      end

      has_summary
    end

    def attribute(name, type, opts = {})
      attributes[name] = opts

      default = opts[:default]

      if has_default = opts.key?(:default)
        defaults[name] = default
      end

      define_method(name) do
        return @cache[name] if @cache.key?(name)

        @cache[name] =
          if manifest[:entity].key?(name)
            manifest[:entity][name]
          else
            default
          end
      end

      define_method(:"#{name}=") do |val|
        unless has_default && val == default
          CFoundry::Validator.validate_type(val, type)
        end

        @cache[name] = val

        @manifest ||= {}
        @manifest[:entity] ||= {}

        old = @manifest[:entity][name]
        @changes[name] = [old, val] if old != val
        @manifest[:entity][name] = val

        @diff[name] = val
      end
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

      define_method(name) do
        return @cache[name] if @cache.key?(name)

        @cache[name] =
          if @manifest && @manifest[:entity].key?(name)
            @client.send(:"make_#{obj}", @manifest[:entity][name])
          elsif url = send("#{name}_url")
            @client.send(:"#{obj}_from", url)
          else
            default
          end
      end

      define_method(:"#{name}_url") do
        manifest[:entity][:"#{name}_url"]
      end

      define_method(:"#{name}=") do |val|
        klass = self.class.objects[obj]

        unless has_default && val == default
          CFoundry::Validator.validate_type(val, klass)
        end

        @manifest ||= {}
        @manifest[:entity] ||= {}

        old = @manifest[:entity][:"#{name}_guid"]
        if old != (val && val.guid)
          old_obj =
            @cache[name] || klass.new(@client, old, @manifest[:entity][name])

          @changes[name] = [old_obj, val]
        end

        @cache[name] = val

        @manifest[:entity][:"#{name}_guid"] =
          @diff[:"#{name}_guid"] = val && val.guid
      end
    end

    def to_many(plural, opts = {})
      to_many_relations[plural] = opts

      singular = plural.to_s.sub(/s$/, "").to_sym

      include QUERIES[singular]

      object = opts[:as] || singular

      kls = object.to_s.capitalize.gsub(/(.)_(.)/) do
        $1 + $2.upcase
      end

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

      define_method(:"#{plural}_url") do
        manifest[:entity][:"#{plural}_url"]
      end

      define_method(:"add_#{singular}") do |x|
        klass = self.class.objects[object]

        CFoundry::Validator.validate_type(x, klass)

        if cache = @cache[plural]
          cache << x unless cache.include?(x)
        end

        @client.base.request_path(
          Net::HTTP::Put,
          ["v2", plural_object_name, @guid, plural, x.guid],
          :accept => :json)
      end

      define_method(:"remove_#{singular}") do |x|
        klass = self.class.objects[object]

        CFoundry::Validator.validate_type(x, klass)

        if cache = @cache[plural]
          cache.delete(x)
        end

        @client.base.request_path(
          Net::HTTP::Delete,
          ["v2", plural_object_name, @guid, plural, x.guid],
          :accept => :json)
      end

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

    def has_summary(actions = {})
      define_method(:summary) do
        @client.base.request_path(
          Net::HTTP::Get,
          ["v2", plural_object_name, @guid, "summary"],
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

            vals = val.collect do |sub|
              obj = @client.send(singular, sub[:guid], true)
              obj.summarize! sub
              obj
            end

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

    def queryable_by(*names)
      klass = self
      singular = object_name
      plural = plural_object_name

      query = QUERIES[singular]

      query.module_eval do
        names.each do |name|
          define_method(:"#{singular}_by_#{name}") do |*args|
            send(:"#{plural}_by_#{name}", *args).first
          end

          define_method(:"#{plural}_by_#{name}") do |val, *args|
            options, _ = args
            options ||= {}
            options[:query] = [name, val]

            query_target(klass).send(plural, options)
          end
        end
      end

      const_set(:Queries, query)

      ClientMethods.module_eval do
        include query
      end
    end

    def self.params_from(args)
      options, _ = args
      options ||= {}
      options[:depth] ||= 1

      params = {}
      options.each do |k, v|
        case k
        when :depth
          params[:"inline-relations-depth"] = v
        when :query
          params[:q] = v.join(":")
        end
      end

      params
    end
  end
end
