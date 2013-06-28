require "spec_helper"

module CFoundry
  module V2
    describe User do
      let(:client) { build(:client) }
      subject { build(:user, client: client) }

      describe '#delete!' do
        describe 'when cloud controller was able to delete the user' do
          before do
            stub_request(:delete, /v2\/users\/.*/).to_return(:status => 200, :body => "", :headers => {})
            client.base.stub(:info).and_return({:authorization_endpoint => 'some_endpoint'})
          end

          it "also removes the user from uaa" do
            CFoundry::UAAClient.any_instance.should_receive(:delete_user)

            subject.delete!({})
          end
        end
      end
    end
  end
end