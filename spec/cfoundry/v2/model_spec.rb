require "spec_helper"

describe CFoundry::V2::Model do
  let(:client) { fake_client }
  let(:guid) { random_string("my-object-guid") }

  subject { described_class.new(guid, client) }

  describe "#delete!" do
    before { stub(client.base).delete_model }

    context "without options" do
      it "sends delete with the object guid and an empty hash" do
        mock(client.base).delete_model(guid, {})
        subject.delete!
      end
    end

    context "with options" do
      it "sends delete with the object guid and options" do
        options = {:excellent => "billandted"}
        mock(client.base).delete_model(guid, options)

        subject.delete!(options)
      end
    end

    it "clears its guid" do
      subject.guid.should be_present
      subject.delete!
      subject.guid.should_not be_present
    end
  end
end
