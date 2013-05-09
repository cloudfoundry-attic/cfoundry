require "spec_helper"

describe CFoundry::V2::AppEvent do
  let(:client) { fake_client }

  let(:app) { fake :app }

  subject { described_class.new("app-event-1", client) }

  it "has an app" do
    subject.app = app
    expect(subject.app).to eq(app)
  end

  describe "#instance_guid" do
    it "has an instance guid" do
      subject.instance_guid = "foo"
      expect(subject.instance_guid).to eq("foo")
    end

    context "when an invalid value is assigned" do
      it "raises a Mismatch exception" do
        expect {
          subject.instance_guid = 123
        }.to raise_error(CFoundry::Mismatch)
      end
    end
  end

  describe "#instance_index" do
    it "has an instance index" do
      subject.instance_index = 123
      expect(subject.instance_index).to eq(123)
    end

    context "when an invalid value is assigned" do
      it "raises a Mismatch exception" do
        expect {
          subject.instance_index = "wrong"
        }.to raise_error(CFoundry::Mismatch)
      end
    end
  end

  describe "#exit_status" do
    it "has an instance index" do
      subject.exit_status = 123
      expect(subject.exit_status).to eq(123)
    end

    context "when an invalid value is assigned" do
      it "raises a Mismatch exception" do
        expect {
          subject.exit_status = "wrong"
        }.to raise_error(CFoundry::Mismatch)
      end
    end
  end

  describe "#exit_description" do
    it "defaults to an empty string" do
      expect(subject.fake.exit_description).to eq("")
    end

    it "has an instance guid" do
      subject.exit_description = "foo"
      expect(subject.exit_description).to eq("foo")
    end

    context "when an invalid value is assigned" do
      it "raises a Mismatch exception" do
        expect {
          subject.exit_description = 123
        }.to raise_error(CFoundry::Mismatch)
      end
    end
  end
end
