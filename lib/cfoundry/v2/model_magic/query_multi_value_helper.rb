module CFoundry::V2
  module ModelMagic
    module QueryValueHelper
      class QueryMultiValue
        attr_accessor :query_values

        def initialize(*query_hashes)
          self.query_values = query_hashes.collect do |query_hash|
            QueryValue.new query_hash
          end
        end

        def collect_values(key)
          query_values.collect do |value|
            "#{key}#{value}"
          end.join(';')
        end
      end
    end
  end
end
