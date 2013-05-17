require "cfoundry/v2/model"

module CFoundry::V2
  class Route < Model
    attribute :host, :string
    validates_format_of :host, :with => /\A[a-z]+([a-z0-9\-]*[a-z0-9]+)?\Z/i
    validates_length_of :host, :maximum => 63
    validates_presence_of :domain
    to_one    :domain
    to_one    :space

    queryable_by :host, :domain_guid

    def name
      "#{host}.#{domain.name}"
    end

    private

    def attribute_for_error(error)
      error.is_a?(CFoundry::RouteHostTaken) ? :host : :base
    end
  end
end
