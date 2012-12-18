module CFoundry
  module Validator
    class << self
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
        when nil
          true
        else
          val.is_a?(Object.const_get(type.to_s.capitalize))
        end
      end

      def validate_type(val, type)
        unless value_matches?(val, type)
          raise CFoundry::Mismatch.new(type, val)
        end
      end
    end
  end
end
