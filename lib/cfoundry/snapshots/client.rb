require "cfoundry/baseclient"
require "cfoundry/snapshots/snapshot"
require "cfoundry/snapshots/job"

module CFoundry
  module Snapshots
    class Client < BaseClient
      attr_accessor :target, :client_id, :token, :trace

      def initialize(target, gateway_name)
        @target = target
        @gateway_name = gateway_name
      end

      def create_snapshot(payload = {})
        response = post(payload,
             "services", "v1", "configurations", @gateway_name, "snapshots",
             :accept => :json, :content => :json)

        Job.new response, self
      end

      def job(job_id)
        get("services", "v1", "configurations", @gateway_name, "jobs", job_id, :accept => :json)
      end
    end
  end
end