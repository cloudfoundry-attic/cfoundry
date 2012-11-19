require "cfoundry/v2/model"

module CFoundry::V2
  class User < Model
    to_many   :spaces
    to_many   :organizations
    to_many   :managed_organizations, :as => :organization
    to_many   :billing_managed_organizations, :as => :organization
    to_many   :audited_organizations, :as => :organization
    to_many   :managed_spaces, :as => :space
    to_many   :audited_spaces, :as => :space
    attribute :admin, :boolean
    to_one    :default_space, :as => :space

    attribute :guid, :string # guid is explicitly set for users

    queryable_by :space_guid, :organization_guid, :managed_organization_guid,
      :billing_managed_organization_guid, :audited_organization_guid,
      :managed_space_guid, :audited_space_guid

    def guid
      @guid
    end

    def guid=(x)
      @guid = x
      super
    end

    alias :admin? :admin

    def change_password!(new, old)
      @client.base.uaa.change_password(@guid, new, old)
    end

    # optional metadata from UAA
    attr_accessor :emails, :name

    def email
      return unless @emails && @emails.first
      @emails.first[:value]
    end

    def given_name
      return unless @name && @name[:givenName] != email
      @name[:givenName]
    end

    def family_name
      return unless @name && @name[:familyName] != email
      @name[:familyName]
    end

    def full_name
      if @name && @name[:fullName]
        @name[:fullName]
      elsif given_name && family_name
        "#{given_name} #{family_name}"
      end
    end
  end
end
