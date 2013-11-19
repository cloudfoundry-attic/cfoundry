require "spec_helper"

module CFoundry
  module V2
    describe Event do
      let(:event) { build(:event, :app_update, changes: 'STOPPED') }

      describe "#metadata" do
        it "contains the request" do
          expect(event.metadata[:request]).to eq('STOPPED')
        end
      end
    end
  end
end
