require "spec_helper"

describe CFoundry::V2::ServiceInstance do
  let(:client) { fake_client }
  let(:gateway_name) { "some-gateway-name" }
  let(:service) { fake :service_instance, :credentials => { :name => gateway_name } }
  let(:gateway_base) { "#{client.target}/services/v1/configurations/#{gateway_name}" }
end
