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
  end
end
