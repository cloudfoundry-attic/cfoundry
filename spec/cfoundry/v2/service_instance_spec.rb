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
