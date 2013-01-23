require "spec_helper"

describe CFoundry::V1::Client do
  let(:client) { CFoundry::V1::Client.new }

  describe "#version" do
    its(:version) { should eq 1 }
  end

  describe "#login" do
    include_examples "client login"
  end

  describe "#login_prompts" do
    include_examples "client login prompts"
  end
end