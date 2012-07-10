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

    alias :spaces :app_spaces
    alias :managed_spaces :managed_app_spaces
    alias :audited_spaces :audited_app_spaces
    alias :default_space :default_app_space
  end
end
