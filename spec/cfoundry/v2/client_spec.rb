require "spec_helper"

module CFoundry
  module V2
    describe Client do
      subject(:client) { build(:client) }

      describe "#register" do
        let(:uaa) { UAAClient.new('http://uaa.example.com') }
        let(:email) { "test@test.com" }
        let(:password) { "secret" }

        subject { client.register(email, password) }

        it "creates the user in uaa and ccng" do
          client.base.stub(:uaa) { uaa }
          uaa.stub(:add_user).with(email, password, {}) { {:id => "1234"} }

          user = build(:user)
          client.stub(:user) { user }
          user.stub(:create!)
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
        include_examples "client login"

        it 'sets the current organization to nil' do
          client.current_organization = "org"
          expect { subject }.to change { client.current_organization }.from("org").to(nil)
        end

        it 'sets the current space to nil' do
          client.current_space = "space"
          expect { subject }.to change { client.current_space }.from("space").to(nil)
        end
      end

      describe "#target=" do
        let(:new_target) { "some-target-url.com"}

        it "sets a new target" do
          expect{client.target = new_target}.to change {client.target}.from("http://api.example.com").to(new_target)
        end

        it "sets a new target on the base client" do
          expect{client.target = new_target}.to change{client.base.target}.from("http://api.example.com").to(new_target)
        end
      end

      describe "#service_instances" do
        let(:client) { build(:client) }

        it "includes user-provided instances" do
          expect(client.base).to receive(:service_instances).with(hash_including(user_provided: true)).and_return([])
          client.service_instances
        end
      end

      describe "#make_service_instance" do
        it "returns a UserProvidedServiceInstance when json[:type] is user_provided_service_instance" do
          json = MultiJson.load(CcApiStub::Helper.load_fixtures(:fake_cc_user_provided_service_instance).to_json, :symbolize_keys => true)
          instance = client.make_service_instance(json)
          expect(instance).to be_a(CFoundry::V2::UserProvidedServiceInstance)

          json = MultiJson.load(CcApiStub::Helper.load_fixtures(:fake_cc_managed_service_instance).to_json, :symbolize_keys => true)
          instance = client.make_service_instance(json)
          expect(instance).to be_a(CFoundry::V2::ManagedServiceInstance)
        end
      end
    end
  end
end
