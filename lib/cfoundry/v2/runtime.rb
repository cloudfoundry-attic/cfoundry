require "cfoundry/v2/model"

module CFoundry::V2
  class Runtime < Model
    attribute :name
    attribute :description
    to_many   :apps
  end
end
