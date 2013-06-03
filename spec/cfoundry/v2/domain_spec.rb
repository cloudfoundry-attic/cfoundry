require "spec_helper"

module CFoundry
  module V2
    describe Domain do
      let(:domain) { build(:domain) }

      it "should have a spaces association" do
        expect(domain.spaces).to eq([])
      end
    end
  end
end
