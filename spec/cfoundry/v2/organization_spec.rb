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
    end
  end
end
