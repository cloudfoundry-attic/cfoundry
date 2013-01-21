require "spec_helper"

describe CFoundry::V1::Client do
  describe "#version" do
    its(:version) { should eq 1 }
  end
end