module CFoundry
  module V2
    module ModelMagic
      module ClientExtensions
        def add_client_methods(klass)
          singular = klass.object_name
          plural = klass.plural_object_name

          define_base_client_methods do
            #
            # def client.MODEL
            #
            define_method(singular) do |guid, *args|
              get("v2", plural, guid,
                :accept => :json,
                :params => ModelMagic.params_from(args)
              )
            end

            #
            # def client.MODELs
            #
            define_method(plural) do |*args|
              all_pages(
                get("v2", plural,
                  :accept => :json,
                  :params => ModelMagic.params_from(args)
                )
              )
            end

            #
            # def client.MODELs_first_page
            #
            define_method(:"#{plural}_first_page") do |*args|
              get("v2", plural,
                :accept => :json,
                :params => ModelMagic.params_from(args)
              )
            end
          end


          define_client_methods do
            #
            # def client.MODEL
            #
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

            #
            # def client.MODELs
            #
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

            #
            # def client.MODELs_first_page
            #
            define_method(:"#{plural}_first_page") do |*args|
              response = @base.send(:"#{plural}_first_page", *args)
              results = response[:resources].collect do |json|
                send(:"make_#{singular}", json)
              end
              {
                  :next_page => !!response[:next_url],
                  :results => results
              }
            end

            #
            # def client.MODEL_from
            #
            define_method(:"#{singular}_from") do |path, *args|
              send(
                :"make_#{singular}",
                @base.get(
                  path,
                  :accept => :json,
                  :params => ModelMagic.params_from(args)))
            end

            #
            # def client.MODELs_from
            #
            define_method(:"#{plural}_from") do |path, *args|
              objs = @base.all_pages(
                @base.get(
                  path,
                  :accept => :json,
                  :params => ModelMagic.params_from(args)))

              objs.collect do |json|
                send(:"make_#{singular}", json)
              end
            end

            #
            # def client.make_MODEL
            #
            define_method(:"make_#{singular}") do |json|
              klass.new(
                json[:metadata][:guid],
                self,
                json)
            end
          end
        end

        private

        def define_client_methods(&blk)
          ClientMethods.module_eval(&blk)
        end

        def define_base_client_methods(&blk)
          BaseClientMethods.module_eval(&blk)
        end
      end
    end
  end
end