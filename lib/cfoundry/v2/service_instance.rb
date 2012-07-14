require "cfoundry/v2/model"

module CFoundry::V2
  class ServiceInstance < Model
    attribute :name
    to_one    :app_space
    to_one    :service_plan
    to_many   :service_bindings
    attribute :credentials
    attribute :vendor_data, :default => ""

    alias :space :app_space
    alias :space= :app_space=
  end
end
