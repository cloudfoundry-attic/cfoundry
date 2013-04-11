require "spec_helper"

describe CFoundry::V2::Organization do
  let(:client) { fake_client }

  subject { CFoundry::V2::Organization.new("organization-1", client) }

  describe "summarization" do
    let(:mymodel) { CFoundry::V2::Organization }
    let(:myobject) { fake(:organization) }
    let(:summary_attributes) { { :name => "fizzbuzz" } }

    subject { myobject }

    it_behaves_like "a summarizeable model"
  end

  it "has quota_definition" do
    quota = fake(:quota_definition)
    subject.quota_definition = quota
    expect(subject.quota_definition).to eq(quota)
  end

  it "has billing_enabled" do
    [true, false].each do |v|
      subject.billing_enabled = v
      expect(subject.billing_enabled).to eq(v)
    end
  end
end
