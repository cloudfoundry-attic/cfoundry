require "cfoundry/v2/model"

module CFoundry::V2
  class Route < Model
    attribute :host, :string
    to_one    :domain
    to_one    :space

    def name
      "#{host}.#{domain.name}"
    end
  end
end
