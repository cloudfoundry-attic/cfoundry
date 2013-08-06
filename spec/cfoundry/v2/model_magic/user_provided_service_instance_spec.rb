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

      describe "#create!" do
        it "sends request to /v2/user_provided_service_instance" do
          stub_request(:post, /.+/).to_return(status: 201,
            body: {
              "metadata" => {"guid" => "user-provided-guid-1"},
              "entity" => {},
            }.to_json,
          )
          space = build(:space)
          instance = client.user_provided_service_instance
          instance.space = space
          instance.name = "user-provided-name"
          instance.create!

          a_request(:post, %r(/v2/user_provided_service_instances)).should have_been_made
        end
      end

      describe "#service_bindings" do
        it "hits the right endpoint" do
          stub_request(:get, %r(/v2/service_instances/.+/service_bindings)).to_return(
            body: '{
  "total_results": 0,
  "total_pages": 1,
  "prev_url": null,
  "next_url": null,
  "resources": []}'
          )

          instance = build(:user_provided_service_instance, :client => client)

          instance.service_bindings
          a_request(:get, %r(/v2/service_instances/#{instance.guid}/service_bindings)).should have_been_made
        end
      end
    end
  end
end
