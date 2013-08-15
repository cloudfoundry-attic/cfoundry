require "spec_helper"

module CFoundry
  module V2
    describe UserProvidedServiceInstance do
      let(:client) { build(:client) }
      subject { build(:user_provided_service_instance, :client => client) }

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
    end
  end
end
