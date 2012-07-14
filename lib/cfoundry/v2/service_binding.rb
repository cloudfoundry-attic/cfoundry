require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceBinding < Model
    attribute :credentials
    attribute :binding_options, :default => {}
    attribute :vendor_data, :default => {}
    to_one    :app
    to_one    :service_instance
  end
end
