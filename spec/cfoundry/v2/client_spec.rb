require "spec_helper"

module CFoundry
  module V2
    describe Client do
      let(:client) { build(:client) }

      describe "#register" do
        let(:uaa) { UAAClient.new }
        let(:email) { "test@test.com" }
        let(:password) { "secret" }

        subject { client.register(email, password) }

        it "creates the user in uaa and ccng" do
          stub(client.base).uaa { uaa }
          stub(uaa).add_user(email, password) { {"id" => "1234"} }

          user = build(:user)
          stub(client).user { user }
          stub(user).create!
          subject
          expect(user.guid).to eq "1234"
        end
      end

      describe "#current_user" do
        subject { client.current_user }
        before { client.token = token }

        context "when there is no token" do
          let(:token) { nil }
          it { should eq nil }
        end

        context "when there is no access_token_data" do
          let(:token) { AuthToken.new("bearer some-access-token", "some-refresh-token") }
          it { should eq nil }
        end

        context "when there is access_token_data" do
          let(:token_data) { {:user_id => "123", :email => "guy@example.com"} }
          let(:auth_header) { Base64.encode64("{}#{MultiJson.encode(token_data)}") }
          let(:token) do
            CFoundry::AuthToken.new("bearer #{auth_header}", "some-refresh-token")
          end

          it { should be_a User }
          its(:guid) { should eq "123" }
          its(:emails) { should eq [{:value => "guy@example.com"}] }
        end
      end

      describe "#version" do
        its(:version) { should eq 2 }
      end

      describe "#login_prompts" do
        include_examples "client login prompts"
      end

      describe "#login" do
        include_examples "client login" do
          it 'sets the current organization to nil' do
            client.current_organization = "org"
            expect { subject }.to change { client.current_organization }.from("org").to(nil)
          end

          it 'sets the current space to nil' do
            client.current_space = "space"
            expect { subject }.to change { client.current_space }.from("space").to(nil)
          end
        end
      end
    end
  end
end