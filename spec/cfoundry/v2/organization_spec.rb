require "spec_helper"

module CFoundry
  module V2
    describe Organization do
      let(:client) { build(:client) }
      let(:organization) { build(:organization, :client => client) }

      it_behaves_like "a summarizeable model" do
        subject { organization }
        let(:summary_attributes) { {:name => "fizzbuzz"} }
      end

      it "has quota_definition" do
        quota = build(:quota_definition)
        organization.quota_definition = quota
        expect(organization.quota_definition).to eq(quota)
      end

      it "has billing_enabled" do
        [true, false].each do |v|
          organization.billing_enabled = v
          expect(organization.billing_enabled).to eq(v)
        end
      end

      describe "#delete_user_from_all_roles" do
        let(:user) { build(:user) }
        let(:organization) do
          build(:organization, client: client, users: [user],
            managers: [user], billing_managers: [user], auditors: [user])
        end

        let(:status) { 201 }

        let(:delete_from_org_response) do
          <<-json
{
  "metadata": {
    "guid": "24113d03-204b-4d23-b320-4127ee9c0006",
    "url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006",
    "created_at": "2013-08-17T00:47:03+00:00",
    "updated_at": "2013-08-17T00:47:04+00:00"
  },
  "entity": {
    "name": "dsabeti-the-org",
    "billing_enabled": false,
    "quota_definition_guid": "b72b1acb-ff4f-468d-99c0-05cd91012b62",
    "status": "active",
    "quota_definition_url": "/v2/quota_definitions/b72b1acb-ff4f-468d-99c0-05cd91012b62",
    "spaces_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006/spaces",
    "domains_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006/domains",
    "users_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006/users",
    "managers_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006/managers",
    "billing_managers_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006/billing_managers",
    "auditors_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006/auditors",
    "app_events_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006/app_events"
  }
}
json
        end

        let(:delete_from_space_response) do
          <<-json
{
  "metadata": {
    "guid": "6825e318-7a3f-4d50-a2a9-dd7088c95347",
    "url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347",
    "created_at": "2013-10-18T00:54:34+00:00",
    "updated_at": null
  },
  "entity": {
    "name": "asdf",
    "organization_guid": "24113d03-204b-4d23-b320-4127ee9c0006",
    "organization_url": "/v2/organizations/24113d03-204b-4d23-b320-4127ee9c0006",
    "developers_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/developers",
    "managers_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/managers",
    "auditors_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/auditors",
    "apps_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/apps",
    "domains_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/domains",
    "service_instances_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/service_instances",
    "app_events_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/app_events",
    "events_url": "/v2/spaces/6825e318-7a3f-4d50-a2a9-dd7088c95347/events"
  }
}
          json
        end

        let(:space1) do
          build(:space, organization: organization,
            developers: [user], auditors: [user], managers: [user])
        end

        let(:space2) do
          build(:space, organization: organization,
            developers: [user], auditors: [user], managers: [user])
        end

        before do
          organization.stub(:spaces).and_return([space1, space2])

          stub_request(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/users/#{user.guid}").to_return(status: status, body: delete_from_org_response)
          stub_request(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/managers/#{user.guid}").to_return(status: status, body: delete_from_org_response)
          stub_request(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/billing_managers/#{user.guid}").to_return(status: status, body: delete_from_org_response)
          stub_request(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/auditors/#{user.guid}").to_return(status: status, body: delete_from_org_response)

          stub_request(:delete, "http://api.example.com/v2/spaces/#{space1.guid}/developers/#{user.guid}").to_return(status: status, body: delete_from_space_response)
          stub_request(:delete, "http://api.example.com/v2/spaces/#{space1.guid}/managers/#{user.guid}").to_return(status: status, body: delete_from_space_response)
          stub_request(:delete, "http://api.example.com/v2/spaces/#{space1.guid}/auditors/#{user.guid}").to_return(status: status, body: delete_from_space_response)

          stub_request(:delete, "http://api.example.com/v2/spaces/#{space2.guid}/developers/#{user.guid}").to_return(status: status, body: delete_from_space_response)
          stub_request(:delete, "http://api.example.com/v2/spaces/#{space2.guid}/managers/#{user.guid}").to_return(status: status, body: delete_from_space_response)
          stub_request(:delete, "http://api.example.com/v2/spaces/#{space2.guid}/auditors/#{user.guid}").to_return(status: status, body: delete_from_space_response)
        end

        it "removes the given user from all roles in the org and all its spaces" do
          organization.delete_user_from_all_roles(user)

          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/users/#{user.guid}")
          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/managers/#{user.guid}")
          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/billing_managers/#{user.guid}")
          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/organizations/#{organization.guid}/auditors/#{user.guid}")

          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/spaces/#{space1.guid}/auditors/#{user.guid}")
          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/spaces/#{space1.guid}/managers/#{user.guid}")
          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/spaces/#{space1.guid}/developers/#{user.guid}")

          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/spaces/#{space2.guid}/auditors/#{user.guid}")
          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/spaces/#{space2.guid}/managers/#{user.guid}")
          expect(WebMock).to have_requested(:delete, "http://api.example.com/v2/spaces/#{space2.guid}/developers/#{user.guid}")
        end
      end
    end
  end
end
