require "spec_helper"

module CFoundry
  module V2
    describe Domain do
      let(:space) { build(:space) }
      let(:domain) { build(:domain, :spaces => [space]) }

      it "should have a spaces association" do
        expect(domain.spaces).to eq([space])
      end

      describe "#owning_organization" do
        context "when the domain is not persisted" do
          let(:client) { build(:client) }
          let(:domain) { build(:domain, client: client, guid: nil)}
          it "asdf" do
            client.should_not_receive(:owning_organization)
            client.should_receive(:organization)
            domain.owning_organization
          end
        end
      end

      describe "validations" do
        subject { build(:domain) }
        it { should validate_presence_of(:name) }
        it { should allow_value("run.pivotal.io").for(:name) }
        it { should_not allow_value("not-a-url").for(:name) }
        it { should validate_presence_of(:owning_organization) }
      end

      describe "#system?" do
        let(:params) { {} }
        let(:domain) { build(:domain, {:owning_organization => nil, client: client}.merge(params)) }
        let(:client) { build(:client) }

        context "when the domain is persisted and has no owning organization" do
          it "returns true" do
            expect(domain.system?).to be_true
          end
        end

        context "when the domain is not persisted" do
          let(:params) { {:guid => nil} }

          it "returns false" do
            expect(domain.system?).to be_false
          end
        end

        context "when the domain has an owning org" do
          let(:params) { {:owning_organization => org} }
          let(:org) { build(:organization) }

          it "returns false" do
            expect(domain.system?).to be_false
          end
        end
      end
    end
  end
end
