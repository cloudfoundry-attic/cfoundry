require "spec_helper"

describe CFoundry::UAAClient do
  let(:target) { "https://uaa.example.com" }
  let(:uaa) { CFoundry::UAAClient.new(target) }

  describe '#prompts' do
    subject { uaa.prompts }

    # GET (target)/login
    it "receives the prompts from /login" do
      stub_request(:get, "#{target}/login").to_return :status => 200,
        :body => <<EOF
          {
            "timestamp": "2012-11-08T13:32:18+0000",
            "commit_id": "ebbf817",
            "app": {
              "version": "1.2.6",
              "artifact": "cloudfoundry-identity-uaa",
              "description": "User Account and Authentication Service",
              "name": "UAA"
            },
            "prompts": {
              "username": [
                "text",
                "Email"
              ],
              "password": [
                "password",
                "Password"
              ]
            }
          }
EOF

      expect(subject).to eq(
        :username => ["text", "Email"],
        :password => ["password", "Password"])
    end
  end

  describe '#authorize' do
    let(:username) { "foo@bar.com" }
    let(:password) { "test" }

    subject { uaa.authorize(:username => username, :password => password) }

    it 'returns the token on successful authentication' do
      stub_request(
        :post,
        "#{target}/oauth/authorize"
      ).with(
        :query => {
          "client_id" => uaa.client_id,
          "redirect_uri" => uaa.redirect_uri,
          "response_type" => "token"
        }
      ).to_return(
        :status => 302,
        :headers => {
          "Location" => "#{uaa.redirect_uri}#access_token=bar&token_type=foo&fizz=buzz&foo=bar"
        }
      )

      expect(subject).to eq "foo bar"
    end

    it 'raises CFoundry::Denied if authentication fails' do
      stub_request(
        :post,
        "#{target}/oauth/authorize"
      ).with(
        :query => {
          "client_id" => uaa.client_id,
          "redirect_uri" => uaa.redirect_uri,
          "response_type" => "token"
        }
      ).to_return(
        :status => 401,
        :headers => {
          "Location" => "#{uaa.redirect_uri}#access_token=bar&token_type=foo&fizz=buzz&foo=bar"
        },
        :body => <<EOF
          {
            "error": "unauthorized",
            "error_description": "Bad credentials"
          }
EOF
      )

      expect { subject }.to raise_error(
        CFoundry::Denied, "401: Bad credentials")
    end
  end

  describe '#users' do
    subject { uaa.users }

    it 'requests /Users' do
      req = stub_request(:get, "#{target}/Users").to_return(
        :body => '{ "fake_data": "123" }')
      expect(subject).to eq({ :fake_data => "123" })
      expect(req).to have_been_requested
    end
  end

  describe '#change_password' do
    let(:guid) { "foo-bar-baz" }
    let(:old) { "old-pass" }
    let(:new) { "new-pass" }

    subject { uaa.change_password(guid, new, old) }

    it 'sends a password change request' do
      req = stub_request(
        :put,
        "#{target}/Users/#{guid}/password"
      ).with(
        :body => {
          :password => new,
          :oldPassword => old
        },
        :headers => {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      ).to_return(
        :status => 200,
        :body => <<EOF
          {
            "status": "ok",
            "message": "password_updated"
          }
EOF
      )


      subject

      expect(req).to have_been_requested
    end
  end

  describe '#password_score' do
    let(:password) { "password" }
    let(:response) { MultiJson.encode({}) }

    subject { uaa.password_score(password) }

    before do
      @request = stub_request(:post, "#{target}/password/score").with(
        :body => {:password => password, },
        :headers => { "Accept" => "application/json" }
      ).to_return(
        :status => 200,
        :body => response
      )
    end

    it 'sends a password change request' do
      subject
      expect(@request).to have_been_requested
    end

    context 'when the score is 0 and the required is 0' do
      let(:response) { MultiJson.encode "score" => 0, "requiredScore" => 0 }
      it { should == :good }
    end

    context 'when the score is less than the required core' do
      let(:response) { MultiJson.encode "score" => 1, "requiredScore" => 5 }
      it { should == :weak }
    end

    context 'and the score is equal to the required score' do
      let(:response) { MultiJson.encode "score" => 5, "requiredScore" => 5 }
      it { should == :good }
    end

    context 'and the score is greater than the required score' do
      let(:response) { MultiJson.encode "score" => 6, "requiredScore" => 5 }
      it { should == :good }
    end

    context 'and the score is 10' do
      let(:response) { MultiJson.encode "score" => 10, "requiredScore" => 5 }
      it { should == :strong }
    end

    context 'and the score is 10' do
      let(:response) { MultiJson.encode "score" => 10, "requiredScore" => 10 }
      it { should == :strong }
    end

    context 'and the score is invalid' do
      let(:response) { MultiJson.encode "score" => 11, "requiredScore" => 5 }
      it { should == :weak }
    end
  end
end
