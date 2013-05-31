require "spec_helper"

module CFoundry
  module V2
    describe Space do
      it_behaves_like "a summarizeable model" do
        let(:summary_attributes) { {:name => "fizzbuzz"} }
        let(:client) { build(:client) }
        subject { build(:space, :client => client) }
      end
    end
  end
end
