require "cfoundry/v2/model"

require "cfoundry/snapshots/client"

module CFoundry::V2
  class ServiceInstance < Model
    attribute :name, :string
    attribute :credentials, :hash, :read_only => true
    to_one    :space
    to_one    :service_plan
    to_many   :service_bindings

    scoped_to_space

    queryable_by :name, :space_guid, :service_plan_guid, :service_binding_guid

    def snapshot!(name = nil)
      snapshot_client.create_snapshot(:name => name)
    end

    def snapshot_client
      @snapshot_client ||= CFoundry::Snapshots::Client.new(@client.target, credentials[:name])
    end
  end
end
