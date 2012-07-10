require "cfoundry/v2/model"

module CFoundry::V2
  class AppSpace < Model
    attribute :name
    to_one    :organization
    to_many   :developers, :as => :user
    to_many   :managers, :as => :user
    to_many   :auditors, :as => :user
    to_many   :apps
    to_many   :domains
  end
end
