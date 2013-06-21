require "spec_helper"

describe CFoundry::Client do
  before do
    CFoundry::V2::Client.any_instance.stub(:info)
  end

  subject { CFoundry::Client.new('http://example.com') }

  it "returns a v2 client" do
    subject.should be_a(CFoundry::V2::Client)
  end
end
