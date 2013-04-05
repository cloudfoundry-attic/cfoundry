require "spec_helper"

describe CFoundry::V2::QuotaDefinition do
  let(:client) { fake_client }

  subject { CFoundry::V2::QuotaDefinition.new("quota-definition-1", client) }

  it "has guid" do
    expect(subject.guid).to eq("quota-definition-1")
  end

  it "has name" do
    subject.name = "name"
    expect(subject.name).to eq("name")
  end

  it "has non_basic_services_allowed" do
    [true, false].each do |v|
      subject.non_basic_services_allowed = v
      expect(subject.non_basic_services_allowed).to eq(v)
    end
  end

  it "has total_services" do
    [0, 1].each do |v|
      subject.total_services = v
      expect(subject.total_services).to eq(v)
    end
  end

  it "has total_services" do
    [0, 1].each do |v|
      subject.total_services = v
      expect(subject.total_services).to eq(v)
    end
  end

  describe "querying" do
    let(:foo) { fake(:quota_definition, :name => "foo") }
    let(:bar) { fake(:quota_definition, :name => "bar") }
    let(:baz) { fake(:quota_definition, :name => "baz") }

    let(:quota_definitions) { [foo, bar, baz] }

    let(:client) { fake_client :quota_definitions => quota_definitions }

    it "is queryable by name" do
      quota = quota_definitions.last
      expect(client.quota_definition_by_name("bar")).to eq(bar)
    end
  end
end
