require "spec_helper"

module CFoundry
  module V2
    describe AppEvent do
      let(:app_event) { build(:app_event) }

      it "has an app" do
        app = build(:app)
        app_event.app = app
        expect(app_event.app).to eq(app)
      end

      describe "#instance_guid" do
        it "has an instance guid" do
          app_event.instance_guid = "foo"
          expect(app_event.instance_guid).to eq("foo")
        end

        context "when an invalid value is assigned" do
          it "raises a Mismatch exception" do
            expect {
              app_event.instance_guid = 123
            }.to raise_error(Mismatch)
          end
        end
      end

      describe "#instance_index" do
        it "has an instance index" do
          app_event.instance_index = 123
          expect(app_event.instance_index).to eq(123)
        end

        context "when an invalid value is assigned" do
          it "raises a Mismatch exception" do
            expect {
              app_event.instance_index = "wrong"
            }.to raise_error(Mismatch)
          end
        end
      end

      describe "#exit_status" do
        it "has an instance index" do
          app_event.exit_status = 123
          expect(app_event.exit_status).to eq(123)
        end

        context "when an invalid value is assigned" do
          it "raises a Mismatch exception" do
            expect {
              app_event.exit_status = "wrong"
            }.to raise_error(Mismatch)
          end
        end
      end

      describe "#exit_description" do
        it "defaults to an empty string" do
          expect(app_event.fake.exit_description).to eq("")
        end

        it "has an instance guid" do
          app_event.exit_description = "foo"
          expect(app_event.exit_description).to eq("foo")
        end

        context "when an invalid value is assigned" do
          it "raises a Mismatch exception" do
            expect {
              app_event.exit_description = 123
            }.to raise_error(Mismatch)
          end
        end
      end
    end
  end
end
