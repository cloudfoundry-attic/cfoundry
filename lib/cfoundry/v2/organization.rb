require "cfoundry/v2/model"

module CFoundry::V2
  class Organization < Model
    attribute :name, :string
    to_many   :spaces
    to_many   :domains
    to_many   :users
    to_many   :managers, :as => :user
    to_many   :billing_managers, :as => :user
    to_many   :auditors, :as => :user

    queryable_by :name, :space_guid, :user_guid, :manager_guid,
      :billing_manager_guid, :auditor_guid

    has_summary
  end
end
