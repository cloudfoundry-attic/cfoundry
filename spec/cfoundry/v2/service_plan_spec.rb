require "spec_helper"

module CFoundry
  module V2
    describe ServicePlan do
      let(:client) { build(:client) }

      subject do
        build(:service_plan)
      end

      before :each do
stub_request(:get, /\/service_plans\/service-plan-guid-\d{1,2}/).to_return :status => 200,
          :headers => {'Content-Type' => 'application/json'},
          :body => <<EOF
  {
    "metadata": {
      "guid": "d1251ac1-fe42-4b4a-84d4-e31e95b547d8",
      "url": "/v2/service_plans/d1251ac1-fe42-4b4a-84d4-e31e95b547d8",
      "created_at": "2013-08-28T12:28:35+04:00",
      "updated_at": "2013-08-28T12:33:27+04:00"
    },
    "entity": {
      "name": "free",
      "free": true,
      "description": "free as in beer",
      "unique_id": "0aa2f82c-6918-41df-b676-c275b5954ed7",
      "extra": "",
      "public": true
    }
  }
EOF
      end

      let(:uuid) { "4692e0ca-25ed-495e-9ae1-fcb0bcf26a96" }

      it "has unique_id that can be mutated" do
        subject.unique_id.should == "0aa2f82c-6918-41df-b676-c275b5954ed7"

        subject.unique_id = uuid
        subject.unique_id.should eq(uuid)
      end

      it "has free/paid indicator attribute" do
        subject.free.should be_true
      end

      it "has a boolean 'public' attribute" do
        expect(subject.public).to be_true
      end
    end
  end
end
