require "spec_helper"

describe CFoundry::Client do
  before do
    CFoundry::V2::Client.any_instance.stub(:info)
  end

  subject { CFoundry::Client.get('http://example.com') }

  it "returns a v2 client" do
    subject.should be_a(CFoundry::V2::Client)
  end

  describe "service_instances" do
    let(:client) { build(:client) }

    it "defaults to true when the :user_provided option is not provided" do
      client.base.should_receive(:service_instances).with(user_provided: true).and_return([])
      client.service_instances
    end

    it "calls super with true when :user_provded=true" do
      client.base.should_receive(:service_instances).with(user_provided: true).and_return([])
      client.service_instances(user_provided: true)
    end

    it "calls super with false when :user_provided=false" do
      client.base.should_receive(:service_instances).with(user_provided: false).and_return([])
      client.service_instances(user_provided: false)
    end
  end
end
