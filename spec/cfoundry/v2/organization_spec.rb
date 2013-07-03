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

      describe "Querying" do
        describe "by :name" do
          let(:query_param) { "My Org" }

          let(:matching_org) do
            org = CcApiStub::Helper.load_fixtures("fake_cc_organization").symbolize_keys
            org[:metadata] = org[:metadata].symbolize_keys
            org[:entity] = org[:entity].symbolize_keys

            org[:entity][:name] = query_param
            org
          end

          let(:non_matching_org) do
            org = CcApiStub::Helper.load_fixtures("fake_cc_organization").symbolize_keys
            org[:metadata] = org[:metadata].symbolize_keys
            org[:entity] = org[:entity].symbolize_keys
            org[:metadata][:guid] = "organization-id-2"

            org[:entity][:name] = "organization-name-2"
            org
          end

          context "when there are two orgs and one match" do
            before do
              client.base.stub(:organizations).and_return([non_matching_org, matching_org])
            end

            context "when queried with #organizations" do
              subject { client.organizations(:query => [:name, query_param]) }

              it "returns the org with the given name" do
                expect(subject.size).to eq 1
                expect(subject[0].name).to eq query_param
              end
            end

            context "when queried with #organzations_by_name" do
              subject { client.organizations_by_name(query_param) }

              it "returns the org with the given name" do
                expect(subject.size).to eq 1
                expect(subject[0].name).to eq query_param
              end
            end

            context "when queried with #organization_by_name" do
              subject { client.organization_by_name(query_param) }

              it "returns the org with the given name" do
                expect(subject).to be_a CFoundry::V2::Organization
                expect(subject.name).to eq query_param
              end
            end
          end

          context "when there are orgs but no matches" do
            before do
              client.base.stub(:organizations).and_return([non_matching_org])
            end

            context "when queried with #organizations" do
              subject { client.organizations(:query => [:name, query_param]) }

              it "returns an empty list" do
                expect(subject).to be_empty
              end
            end

            context "when queried with #organzations_by_name" do
              subject { client.organizations_by_name(query_param) }

              it "returns an empty list" do
                expect(subject).to be_empty
              end
            end

            context "when queried with #organization_by_name" do
              subject { client.organization_by_name(query_param) }

              it "returns nil" do
                expect(subject).to be nil
              end
            end

          end

          context "when there are no orgs" do
            before do
              client.base.stub(:organizations).and_return([])
            end

            context "when queried with #organizations" do
              subject { client.organizations(:query => [:name, query_param]) }

              it "returns an empty list" do
                expect(subject).to be_empty
              end
            end

            context "when queried with #organzations_by_name" do
              subject { client.organizations_by_name(query_param) }

              it "returns an empty list" do
                expect(subject).to be_empty
              end
            end

            context "when queried with #organization_by_name" do
              subject { client.organization_by_name(query_param) }

              it "returns nil" do
                expect(subject).to be nil
              end
            end

          end
        end
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
    end
  end
end
