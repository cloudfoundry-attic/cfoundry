require "cfoundry/v2/model"

module CFoundry::V2
  class User < Model
    to_many   :app_spaces
    to_many   :organizations
    to_many   :managed_organizations, :as => :organization
    to_many   :billing_managed_organizations, :as => :organization
    to_many   :audited_organizations, :as => :organization
    to_many   :managed_app_spaces, :as => :app_space
    to_many   :audited_app_spaces, :as => :app_space
    attribute :admin
    to_one    :default_app_space, :as => :app_space

    attribute :guid # guid is explicitly set for users

    alias :admin? :admin

    alias :spaces :app_spaces
    alias :managed_spaces :managed_app_spaces
    alias :audited_spaces :audited_app_spaces
    alias :default_space :default_app_space

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
