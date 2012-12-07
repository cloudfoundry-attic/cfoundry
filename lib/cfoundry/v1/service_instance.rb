require "cfoundry/v1/model"

module CFoundry::V1
  class ServiceInstance < Model
    self.base_object_name = :service

    attribute :name,       :string,   :guid => true
    attribute :created,    :integer,  :at => [:meta, :created]
    attribute :updated,    :integer,  :at => [:meta, :updated]
    attribute :tags,       [:string], :at => [:meta, :tags]
    attribute :type,       :string
    attribute :vendor,     :string
    attribute :version,    :string
    attribute :tier,       :string
    attribute :properties, :hash

    define_client_methods

    alias_method :created_unix, :created
    alias_method :updated_unix, :updated

    # Timestamp of when the service was created.
    def created
      Time.at(created_unix)
    end

    # Timestamp of when the service was last updated.
    def updated
      Time.at(updated_unix)
    end
  end
end
