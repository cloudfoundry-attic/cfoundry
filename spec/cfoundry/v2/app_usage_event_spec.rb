require "spec_helper"

module CFoundry
  module V2
    describe AppUsageEvent do
      let(:app_usage_event) { build(:app_usage_event, state: 'STOPPED') }

      describe "#state" do
        it "returns the state" do
          expect(app_usage_event.state).to eq('STOPPED')
        end
      end
    end
  end
end
