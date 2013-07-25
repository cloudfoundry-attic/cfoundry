require "spec_helper"

module CFoundry
  module V2
    describe ServiceInstance do
      let(:client) { build(:client) }
      subject { build(:service_instance, :client => client) }

      describe "space" do
        let(:space) { build(:space) }

        it "has a space" do
          subject.space = space
          expect(subject.space).to eq(space)
        end

        context "when an invalid value is assigned" do
          it "raises a Mismatch exception" do
            expect {
              subject.space = [build(:organization)]
            }.to raise_error(CFoundry::Mismatch)
          end
        end
      end

      describe "service_plan" do
        let(:service_plan) { build(:service_plan) }

        it "has a service plan" do
          subject.service_plan = service_plan
          expect(subject.service_plan).to eq(service_plan)
        end

        context "when an invalid value is assigned" do
          it "raises a Mismatch exception" do
            expect {
              subject.space = [build(:organization)]
            }.to raise_error(CFoundry::Mismatch)
          end
        end
      end

      describe "fetching the service instances" do
        let(:example_response) do
         '{
  "total_results": 2,
  "total_pages": 1,
  "prev_url": null,
  "next_url": null,
  "resources": [
    {
      "metadata": {
        "guid": "2148b3c4-3d3d-4361-87a3-1b4bf834cdea",
        "url": "/v2/service_instances/2148b3c4-3d3d-4361-87a3-1b4bf834cdea",
        "created_at": "2013-07-24 00:32:23 +0000",
        "updated_at": null
      },
      "entity": {
        "name": "user-provided-6a19d",
        "credentials": {
          "thing": "a"
        },
        "space_guid": "15ee90c2-8654-40c9-a311-ecfef8cbc921",
        "space_url": "/v2/spaces/15ee90c2-8654-40c9-a311-ecfef8cbc921",
        "service_bindings_url": "/v2/service_instances/2148b3c4-3d3d-4361-87a3-1b4bf834cdea/service_bindings"
      }
    },
    {
      "metadata": {
        "guid": "746c36b0-4b5f-4e46-876a-2948804ef464",
        "url": "/v2/service_instances/746c36b0-4b5f-4e46-876a-2948804ef464",
        "created_at": "2013-07-24 00:32:33 +0000",
        "updated_at": null
      },
      "entity": {
        "name": "rds-mysql-3991f",
        "credentials": {
          "name": "da2f110d519d848a1a677f8df77890cc3",
          "hostname": "mysql-service-public.cze9ndyywtkf.us-east-1.rds.amazonaws.com",
          "host": "mysql-service-public.cze9ndyywtkf.us-east-1.rds.amazonaws.com",
          "port": 3306,
          "user": "ufZEqKvAXQogC",
          "username": "ufZEqKvAXQogC",
          "password": "p8QGNHykcSTu2",
          "node_id": "rds_mysql_node_10mb_0"
        },
        "service_plan_guid": "2c7ab67d-4354-46b5-8423-b19ef6e4b50a",
        "space_guid": "15ee90c2-8654-40c9-a311-ecfef8cbc921",
        "gateway_data": {
          "plan": "10mb",
          "version": "n/a"
        },
        "dashboard_url": null,
        "space_url": "/v2/spaces/15ee90c2-8654-40c9-a311-ecfef8cbc921",
        "service_plan_url": "/v2/service_plans/2c7ab67d-4354-46b5-8423-b19ef6e4b50a",
        "service_bindings_url": "/v2/service_instances/746c36b0-4b5f-4e46-876a-2948804ef464/service_bindings"
      }
    }
  ]
}'
        end

        context "when there is a current org and a current space" do
          let(:org) { build(:organization) }
          let(:space) { build(:space, organization: org) }
          let(:client) { build(:client, current_organization: org, current_space: space) }

          it "gets both user-provided and cf-managed service instances" do
            http_stub = stub_request(:get, "#{client.target}/v2/spaces/#{space.guid}/service_instances?inline-relations-depth=1&return_user_provided_service_instances=true").to_return(:status => 200, :body => example_response)
            client.service_instances
            http_stub.should have_been_requested
          end

          describe "via service_instance_from" do
            it "defaults to true when user_provided is set to a bogus value (not true or false)" do
              http_stub = stub_request(:get, "#{client.target}/v2/spaces/#{space.guid}/service_instances?inline-relations-depth=1&return_user_provided_service_instances=true").to_return(:status => 200, :body => example_response)
              client.service_instances(user_provided: 'some_non-boolean_value')
              http_stub.should have_been_requested
            end
          end
        end
      end

      describe 'query params' do
        it 'allows query by name' do
          client.should respond_to(:service_instance_by_name)
        end

        it 'allows query by space_guid' do
          client.should respond_to(:service_instance_by_space_guid)
        end

        it 'allows query by gateway_name' do
          client.should respond_to(:service_instance_by_gateway_name)
        end

        it 'allows query by service_plan_guid' do
          client.should respond_to(:service_instance_by_service_plan_guid)
        end

        it 'allows query by service_binding_guid' do
          client.should respond_to(:service_instance_by_service_binding_guid)
        end
      end
    end
  end
end
