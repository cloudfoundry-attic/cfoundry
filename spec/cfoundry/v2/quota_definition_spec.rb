require "spec_helper"

module CFoundry
  module V2
    describe QuotaDefinition do
      let(:quota_definition) { build(:quota_definition) }

      it "has guid" do
        quota_definition.guid = "quota-definition-1"
        expect(quota_definition.guid).to eq("quota-definition-1")
      end

      it "has name" do
        quota_definition.name = "name"
        expect(quota_definition.name).to eq("name")
      end

      it "has non_basic_services_allowed" do
        [true, false].each do |v|
          quota_definition.non_basic_services_allowed = v
          expect(quota_definition.non_basic_services_allowed).to eq(v)
        end
      end

      it "has total_services" do
        [0, 1].each do |v|
          quota_definition.total_services = v
          expect(quota_definition.total_services).to eq(v)
        end
      end

      it "has total_services" do
        [0, 1].each do |v|
          quota_definition.total_services = v
          expect(quota_definition.total_services).to eq(v)
        end
      end

      describe "querying" do
        let(:client) { build(:client) }

        it "is queryable by name" do
          mock(client).quota_definitions({:query=>[:name, "quota-name"]}) {[]}

          client.quota_definition_by_name("quota-name")
        end
      end
    end
  end
end
