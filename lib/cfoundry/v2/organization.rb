require "cfoundry/v2/model"

module CFoundry::V2
  class Organization < Model
    attribute :name
    to_many   :app_spaces
    to_many   :domains
    to_many   :users
    to_many   :managers, :as => :user
    to_many   :billing_managers, :as => :user
    to_many   :auditors, :as => :user

    alias :spaces :app_spaces
  end
end
