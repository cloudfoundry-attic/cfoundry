require "cfoundry/v2/model"

module CFoundry::V2
  class Runtime < Model
    attribute :name, :string
    attribute :description, :string
    to_many   :apps

    queryable_by :name, :app_guid
  end
end
