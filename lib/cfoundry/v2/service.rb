require "cfoundry/v2/model"

module CFoundry::V2
  class Service < Model
    attribute :label, String
    attribute :provider, String
    attribute :url, :url
    attribute :description, String
    attribute :version, String
    attribute :info_url, :url
    attribute :acls, { "users" => [String], "wildcards" => [String] },
      :default => nil
    attribute :timeout, Integer, :default => nil
    attribute :active, :boolean, :default => false
    to_many   :service_plans

    queryable_by :service_plan_guid
  end
end
