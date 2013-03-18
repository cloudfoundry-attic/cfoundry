require "spec_helper"

describe CFoundry::V2::Domain do
  let(:client) { fake_client }

  subject { CFoundry::V2::Domain.new("domain-id-1", client) }

  it "should have a spaces association" do
    expect(subject.spaces).to eq([])
  end
end
