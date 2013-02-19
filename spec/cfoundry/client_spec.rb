require 'spec_helper'

describe CFoundry::Client do
  subject { CFoundry::Client.new('http://example.com') }

  it "returns a v1 client when used on a v1 target" do
    stub_request(:get, "http://example.com/info").to_return(:status => 200, :body => '{"version":1}')
    subject.should be_a(CFoundry::V1::Client)
  end

  it "returns a v2 client when used on a v2 target" do
    stub_request(:get, "http://example.com/info").to_return(:status => 200, :body => '{"version":2}')
    subject.should be_a(CFoundry::V2::Client)
  end
end
