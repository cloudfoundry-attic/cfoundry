require "cfoundry/v2/model"

module CFoundry::V2
  class AppEvent < Model
    to_one :app

    attribute :instance_guid, :string
    attribute :instance_index, :integer
    attribute :exit_status, :integer
    attribute :exit_description, :string, :default => ""
    attribute :timestamp, :string
  end
end
