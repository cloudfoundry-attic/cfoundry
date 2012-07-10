require "cfoundry/v2/model"

module CFoundry::V2
  class Service < Model
    attribute :label
    attribute :provider
    attribute :url
    attribute :description
    attribute :version
    attribute :info_url
    attribute :acls
    attribute :timeout
    attribute :active
    to_many   :service_plans
  end
end
