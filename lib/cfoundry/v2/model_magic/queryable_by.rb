module CFoundry::V2
  module ModelMagic::QueryableBy
    def queryable_by(*names)
      klass = self
      singular = object_name
      plural = plural_object_name

      query = ::CFoundry::V2::QUERIES[singular]

      query.module_eval do
        names.each do |name|
          #
          # def MODEL_by_ATTRIBUTE
          #
          define_method(:"#{singular}_by_#{name}") do |*args|
            send(:"#{plural}_by_#{name}", *args).first
          end

          #
          # def MODELs_by_ATTRIBUTE
          #
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
  end
end
