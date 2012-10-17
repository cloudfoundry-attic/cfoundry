require "cfoundry/v2/model"

module CFoundry::V2
  class Route < Model
    attribute :host, :string
    to_one    :domain
    to_one    :organization

    scoped_to_organization

    def name
      "#{host}.#{domain.name}"
    end
  end
end
