require "cfoundry/v2/model"

module CFoundry::V2
  class Stack < Model
    attribute :name, :string

    queryable_by :name
  end
end
