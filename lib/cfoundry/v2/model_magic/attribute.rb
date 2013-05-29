module CFoundry::V2::ModelMagic
  module Attribute
    def attribute(name, type, opts = {})
      attributes[name] = opts
      json_name = opts[:at] || name

      default = opts[:default]

      if has_default = opts.key?(:default)
        defaults[name] = default
      end

      #
      # def ATTRIBUTE
      #
      define_method(name) do
        return @cache[name] if @cache.key?(name)
        return nil unless persisted?

        @cache[name] =
          if manifest[:entity].key?(json_name)
            manifest[:entity][json_name]
          else
            default
          end
      end

      #
      # def ATTRIBUTE=
      #
      define_method(:"#{name}=") do |val|
        unless has_default && val == default
          CFoundry::Validator.validate_type(val, type)
        end

        @cache[name] = val

        @manifest ||= {}
        @manifest[:entity] ||= {}

        old = @manifest[:entity][json_name]
        @changes[name] = [old, val] if old != val
        @manifest[:entity][json_name] = val

        @diff[json_name] = val
      end
    end
  end
end
