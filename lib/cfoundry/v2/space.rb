require "cfoundry/v2/model"

module CFoundry::V2
  class Space < Model
    attribute :name, :string
    to_one    :organization
    to_many   :developers, :as => :user
    to_many   :managers, :as => :user
    to_many   :auditors, :as => :user
    to_many   :apps
    to_many   :domains
    to_many   :service_instances
  end
end
