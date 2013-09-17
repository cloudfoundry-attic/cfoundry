module CFoundry::V2
  module ModelMagic
    module QueryValueHelper
      class QueryValue
        attr_accessor :comparator, :value
        def initialize(params)
          self.comparator = params[:comparator] || params[:comp] || ':'
          self.value = params[:value]
        end

        def to_s
          "#{comparator_string}#{value_string}"
        end

        def comparator_string
          if comparator.downcase == 'in' || value.is_a?(Array)
            " IN "
          else
            comparator
          end
        end

        def value_string
          if value.is_a? Array
            value.join(",")
          else
            value
          end
        end
      end
    end
  end
end
