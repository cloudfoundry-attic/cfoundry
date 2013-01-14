require 'spec_helper'

describe CFoundry::V2::Client do

  let(:client) { CFoundry::V2::Client.new("https://api.cloudfoundry.com") }

  let(:email) { 'test@test.com' }
  let(:password) { 'secret' }
  let(:uaa) { CFoundry::UAAClient.new }

  describe "#register" do
    subject { client.register(email, password) }

    it "creates the user in uaa and ccng" do
      stub(client.base).uaa { uaa }
      stub(uaa).add_user(email, password) { { "id" => "1234" } }

      user = fake(:user)
      stub(client).user("1234") { user }
      mock(user).create!

      subject
    end
  end
end