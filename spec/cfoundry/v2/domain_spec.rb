require "spec_helper"

module CFoundry
  module V2
    describe Domain do
      let(:space) { build(:space) }
      let(:domain) { build(:domain, :spaces => [space]) }

      it "should have a spaces association" do
        expect(domain.spaces).to eq([space])
      end
    end
  end
end
