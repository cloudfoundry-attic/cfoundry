require 'spec_helper'

describe CFoundry::Client do
  before do
    any_instance_of(CFoundry::V2::Client) { |cli| stub(cli).info }
  end

  subject { CFoundry::Client.new('http://example.com') }

  it "returns a v2 client" do
    subject.should be_a(CFoundry::V2::Client)
  end
end
