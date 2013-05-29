require "cfoundry/validator"
require "cfoundry/v2/model_magic/client_extensions"
require "cfoundry/v2/model_magic/has_summary"
require "cfoundry/v2/model_magic/attribute"
require "cfoundry/v2/model_magic/to_one"
require "cfoundry/v2/model_magic/to_many"
require "cfoundry/v2/model_magic/queryable_by"

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
