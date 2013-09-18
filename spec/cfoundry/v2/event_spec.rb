require "spec_helper"

module CFoundry
  module V2
    describe Event do
      let(:event) { build(:event, :app_update, changes: ['STARTED', 'STOPPED']) }

      describe "#metadata" do
        it "contains the changes" do
          expect(event.metadata[:changes]).to eq(['STARTED', 'STOPPED'])
        end
      end
    end
  end
end
