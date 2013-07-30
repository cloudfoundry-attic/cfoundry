require "spec_helper"

describe CFoundry::Client do
  before do
    CFoundry::V2::Client.any_instance.stub(:info)
  end

  subject { CFoundry::Client.get('http://example.com') }

  it "returns a v2 client" do
    subject.should be_a(CFoundry::V2::Client)
  end

  describe "#service_instances" do
    let(:client) { build(:client) }

    it "includes user-provided instances" do
      client.base.should_receive(:service_instances).with(hash_including(user_provided: true)).and_return([])
      client.service_instances
    end
  end
end
