require "spec_helper"

class TestModel < CFoundry::V2::Model
  attribute :foo, :string
end

module CFoundry
  module V2
    describe ModelMagic do
      it_behaves_like "a summarizeable model" do
        let(:summary_attributes) { {:foo => "abcd"} }
        let(:client) { build(:client) }
        subject { TestModel.new("some-guid-1", client) }
      end
    end
  end
end