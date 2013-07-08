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

            subject.delete!.should be_true
          end
        end

        describe "when cloud controller was unable to delete the user" do
          before do
            client.base.stub(:delete).and_raise(CFoundry::APIError)
          end

          it "allows the exception to bubble up" do
            expect{ subject.delete! }.to raise_error(CFoundry::APIError)
          end
        end
      end
    end
  end
end