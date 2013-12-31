require "cfoundry/validator"
require "cfoundry/v2/model_magic/client_extensions"
require "cfoundry/v2/model_magic/has_summary"
require "cfoundry/v2/model_magic/attribute"
require "cfoundry/v2/model_magic/to_one"
require "cfoundry/v2/model_magic/to_many"
require "cfoundry/v2/model_magic/queryable_by"
require "cfoundry/v2/model_magic/query_value_helper"
require "cfoundry/v2/model_magic/query_multi_value_helper"

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
    include ModelMagic::ClientExtensions
    include ModelMagic::HasSummary
    include ModelMagic::Attribute
    include ModelMagic::ToOne
    include ModelMagic::ToMany
    include ModelMagic::QueryableBy
    include ModelMagic::QueryValueHelper

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
      add_client_methods(klass)
      has_summary
    end

    def scoped_to_organization(relation = :organization)
      @scoped_organization = relation
    end

    def scoped_to_space(relation = :space)
      @scoped_space = relation
    end

    # To query a single attribute using equality,
    # you can use :query => ["attribute", "value"]
    #
    # To query multiple attributes, you can specify
    # a hash of attributes to values, where the values
    # can be:
    #   A single value with equality
    #     :query => {attr1: 'value1', attr2: 'value2'}
    #   Multiple values for an attribute
    #     :query => {attr1: ['value1', 'value2']}
    #   Complex comparisons i.e ('<', '>', '<=', '>=')
    #     :query => {attr1: QueryValue.new(comparator: '>', value: 'VALUE')}
    #
    # QueryValue can be found in CFoundry::V2::ModelMagic::QueryValueHelper
    # You can include this module in your class to access QueryValue directly
    # priting is handled by #to_s
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
          if v.is_a? Array
            params[:q] = v.join(":")
          else
            params[:q] = query_from_hash(v)
          end
        when :user_provided
          params[:"return_user_provided_service_instances"] = v
        else
          params[k] = v
        end
      end

      params
    end

    def self.query_from_hash(query_params)
      query_params.collect do |key, value|
        case value
          when Array
            qv = QueryValue.new(:comp => 'IN', :value => value)
            "#{key}#{qv}"
          when QueryValue
            "#{key}#{value}"
          when QueryMultiValue
            value.collect_values(key)
          else
            "#{key}:#{value}"
        end
      end.join(";")
    end
  end
end
