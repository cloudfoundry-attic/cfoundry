require "spec_helper"

module CFoundry
  module V2
    describe Service do
      let(:client) { build(:client) }

      subject do
        build(:service)
      end

      before :each do
stub_request(:get, /\/services\/service-guid-\d{1,2}/).to_return :status => 200,
          :headers => {'Content-Type' => 'application/json'},
          :body => <<EOF
  {
    "metadata": {
      "guid": "d1251ac1-fe42-4b4a-84d4-e31e95b547d8",
      "url": "/v2/services/d1251ac1-fe42-4b4a-84d4-e31e95b547d8",
      "created_at": "2013-08-28T12:28:35+04:00",
      "updated_at": "2013-08-28T12:33:27+04:00"
    },
    "entity": {
      "label": "rabbitmq",
      "provider": "rabbitherd",
      "url": "http://rabbitmq.com",
      "description": "RabbitMQ service",
      "version": "1.0",
      "info_url": null,
      "active": true,
      "bindable": true,
      "unique_id": "0aa2f82c-6918-41df-b676-c275b5954ed7",
      "extra": "",
      "tags": [

      ],
      "documentation_url": null,
      "service_plans_url": "/v2/services/d1251ac1-fe42-4b4a-84d4-e31e95b547d8/service_plans"
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

      it "has tags" do
        subject.tags.should == []
      end
    end
  end
end
