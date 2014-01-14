require "spec_helper"

describe CFoundry::UAAClient do
  let(:target) { "https://uaa.example.com" }
  let(:uaa) { CFoundry::UAAClient.new(target) }
  let(:auth_header) { "bearer access-token" }

  before do
    uaa.token = CFoundry::AuthToken.new(auth_header)
    CF::UAA::Util.default_logger.level = 1
    stub_request(:get, "#{target}/login").
      to_return :status => 200, :headers => {'Content-Type' => 'application/json'},
        :body => <<EOF
          {
            "timestamp": "2012-11-08T13:32:18+0000",
            "commit_id": "ebbf817", "prompts": {}
          }
EOF
  end

  shared_examples "UAA wrapper" do
    it "converts UAA errors to CFoundry equivalents" do
      uaa.should_receive(:wrap_uaa_errors) { nil }
      subject
    end
  end

  describe '#initialize' do
    it "passes proxy info to the UAA info client" do
      CF::UAA::Info.stub(:new)
      CFoundry::UAAClient.new(target, 'cf', http_proxy: 'http-proxy.example.com', https_proxy: 'https-proxy.example.com')
      expect(CF::UAA::Info).to have_received(:new).with(anything, hash_including(
          http_proxy: 'http-proxy.example.com',
          https_proxy: 'https-proxy.example.com'
      ))
    end
  end

  describe '#prompts' do
    subject { uaa.prompts }

    include_examples "UAA wrapper"

    # GET (target)/login
    it "receives the prompts from /login" do
      stub_request(:get, "#{target}/login").to_return :status => 200,
        :headers => {'Content-Type' => 'application/json'},
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
    let(:creds) { {:username => username, :password => password} }
    let(:state) { 'somestate' }
    let(:redirect_uri) { 'https://uaa.example.com/redirect/cf' }
    let(:auth) { Object.new }
    let(:issuer) { Object.new }

    subject { uaa.authorize(creds) }

    before do
      issuer.stub(:request_token) { auth }
      uaa.stub(:token_issuer) { issuer }
    end

    include_examples "UAA wrapper"

    it 'returns the token on successful authentication' do
      issuer
        .should_receive(:request_token)
        .with(:grant_type => "password",
              :scope => nil,
              :username => username,
              :password => password) { auth }
      expect(subject).to eq auth
    end

    context 'when authorization fails' do
      context 'in the expected way' do
        it 'raises a CFoundry::Denied error' do
          issuer.should_receive(:request_token) { raise CF::UAA::BadResponse.new("401: FooBar") }
          expect { subject }.to raise_error(CFoundry::Denied, "401: Authorization failed")
        end
      end


      context 'in an unexpected way' do
        it 'raises a CFoundry::Denied error' do
          issuer.should_receive(:request_token) { raise CF::UAA::BadResponse.new("no_status_code") }
          expect { subject }.to raise_error(CFoundry::Denied, "400: Authorization failed")
        end
      end

      context "with a CF::UAA::TargetError" do
        before { issuer.stub(:request_token) { raise CF::UAA::TargetError.new("useless info") } }

        it "retries with implicit grant" do
          issuer.should_receive(:implicit_grant_with_creds).with(:username => username, :password => password)
          expect { subject }.to_not raise_error
        end

        it "fails with Denied when given a 401" do
          issuer.stub(:implicit_grant_with_creds) { raise CF::UAA::BadResponse.new("status 401") }
          expect { subject }.to raise_error(CFoundry::Denied, "401: Authorization failed")
        end

        it "fails with Denied when given any other status code" do
          issuer.stub(:implicit_grant_with_creds) { raise CF::UAA::BadResponse.new("no status code") }
          expect { subject }.to raise_error(CFoundry::Denied, "400: Authorization failed")
        end
      end
    end
  end

  describe '#users' do
    subject { uaa.users }

    it 'requests /Users' do
      stub_request(:get, "#{target}/Users").with(
        :headers => { "authorization" => auth_header }
      ).to_return(
        :headers => {'Content-Type' => 'application/json'},
        :body => '{ "resources": [] }'
      )
      expect(subject).to eq({:resources => []})
    end

    context "when there is no token" do
      before { uaa.token = nil }

      it "doesn't blow up" do
        stub_request(:get, "#{target}/Users").to_return(
          :headers => {'Content-Type' => 'application/json'},
          :body => '{ "resources": [] }'
        )
        expect(subject).to eq({:resources => []})
      end
    end
  end

  describe '#change_password' do
    let(:guid) { "foo-bar-baz" }
    let(:old) { "old-pass" }
    let(:new) { "new-pass" }

    subject { uaa.change_password(guid, new, old) }

    include_examples "UAA wrapper"

    it 'sends a password change request' do
      req = stub_request(:put, "#{target}/Users/#{guid}/password").with(
        :headers => {
          "Content-Type" => "application/json;charset=utf-8",
          "Accept" => "application/json;charset=utf-8",
          "Authorization" => auth_header
        }
      ).to_return(
        :status => 200,
        :headers => {'Content-Type' => 'application/json'},
        :body => '{ "status": "ok", "message": "password_updated" }'
      )

      subject

      expect(req).to have_been_requested
    end
  end

  describe '#password_score' do
    let(:password) { "password" }
    let(:response) { MultiJson.encode({}) }

    subject { uaa.password_score(password) }

    include_examples "UAA wrapper"

    before do
      stub_request(:post, "#{target}/password/score").with(
        :body => 'password=password',
        :headers => {
          'Accept' => 'application/json;charset=utf-8',
          'Content-Type' => 'application/x-www-form-urlencoded;charset=utf-8',
        }
      ).to_return(
        :status => 200,
        :headers => {'Content-Type' => 'application/json'},
        :body => response
      )
    end

    context 'when the score is 0 and the required is 0' do
      let(:response) { MultiJson.encode "score" => 0, "requiredScore" => 0 }
      it { should == :good }
    end

    context 'when the score is less than the required score' do
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

  describe "#add_user" do
    let(:email) { 'test@test.com' }
    let(:password) { 'secret' }

    context "without given/family name" do
      subject { uaa.add_user(email, password) }

      context 'with valid data' do
        it "should add a user" do
          req =
          stub_request(:post, "https://uaa.example.com/Users").with(
            :body =>
              { :userName => email,
                :emails => [{ :value => email }],
                :password => password,
                :name => { :givenName => email, :familyName => email }
              }
            ).to_return(
              :status => 200,
              :body => '{ "id" : "id" }',
              :headers => { "Content-Type" => 'application/json' }
            )

          expect(subject).to eq({:id => "id"})
          expect(req).to have_been_requested
        end
      end
    end

    context "with given/family name" do
      let(:givenName) { 'givenName' }
      let(:familyName) { 'familyName' }
      subject { uaa.add_user(email, password, givenName: givenName, familyName: familyName) }

      context 'with valid data' do
        it "should add a user" do
          req =
            stub_request(:post, "https://uaa.example.com/Users").with(
              :body =>
                { :userName => email,
                  :emails => [{ :value => email }],
                  :password => password,
                  :name => { :givenName => givenName, :familyName => familyName }
                }
            ).to_return(
              :status => 200,
              :body => '{ "id" : "id" }',
              :headers => { "Content-Type" => 'application/json' }
            )

          expect(subject).to eq({:id => "id"})
          expect(req).to have_been_requested
        end
      end
    end

  end

  describe "#delete_user" do
    let(:guid) { "123" }
    let!(:req) {
      stub_request(
        :delete,
        "https://uaa.example.com/Users/123"
      ).to_return(:status => 200, :body => '{ "foo": "bar" }')
    }

    subject { uaa }

    it "wraps uaa errors" do
      uaa.should_receive(:wrap_uaa_errors)
      subject.delete_user(guid)
    end

    context 'with valid data' do
      it "should add a user" do
        subject.delete_user(guid)
        expect(req).to have_been_requested
      end
    end
  end

  describe "#wrap_uaa_errors" do
    subject { uaa.send(:wrap_uaa_errors) { raise error } }

    context "when the block raises CF::UAA::BadResponse" do
      let(:error) { CF::UAA::BadResponse }

      it "raises CFoundry::BadResponse" do
        expect { subject }.to raise_exception(CFoundry::BadResponse)
      end
    end

    context "when the block raises CF::UAA::NotFound" do
      let(:error) { CF::UAA::NotFound }

      it "raises CFoundry::NotFound" do
        expect { subject }.to raise_exception(CFoundry::NotFound)
      end
    end

    context "when the block raises CF::UAA::InvalidToken" do
      let(:error) { CF::UAA::InvalidToken }

      it "raises CFoundry::Denied" do
        expect { subject }.to raise_exception(CFoundry::Denied)
      end
    end

    context "when the block raises CF::UAA::TargetError" do
      let(:error) { CF::UAA::TargetError.new({ :error => "foo", :error_description => "bar" }) }

      it "raises CFoundry::UAAError" do
        expect { subject }.to raise_exception(CFoundry::UAAError, "foo: bar")
      end
    end
  end

  describe "#token_issuer" do
    it "has logging level 0 if #trace is true" do
      uaa.trace = true
      expect(uaa.send(:token_issuer).logger.level).to eq -1
    end

    it "sets the log device to STDERR if #trace is true" do
      uaa.trace = true
      expect(uaa.send(:token_issuer).logger.send(:instance_variable_get, :@logdev).dev).to eq STDERR
    end

    it "sets the log device to STDOUT if #trace is false" do
      uaa.trace = false
      expect(uaa.send(:token_issuer).logger.send(:instance_variable_get, :@logdev).dev).to eq STDOUT
    end

    it "has logging level 1 if #trace is false" do
      uaa.trace = false
      expect(uaa.send(:token_issuer).logger.level).to eq 1
    end

    it "passes proxy info to the token issuer" do
      CF::UAA::TokenIssuer.stub(:new).and_call_original
      uaa.http_proxy = 'http-proxy.example.com'
      uaa.https_proxy = 'https-proxy.example.com'

      uaa.send(:token_issuer)

      expect(CF::UAA::TokenIssuer).to have_received(:new).with(anything, anything, anything, hash_including(
          http_proxy: 'http-proxy.example.com',
          https_proxy: 'https-proxy.example.com'
      ))
    end
  end

  describe "#scim" do
    it "has logging level 0 if #trace is true" do
      uaa.trace = true
      expect(uaa.send(:scim).logger.level).to eq -1
    end

    it "has logging level 1 if #trace is false" do
      uaa.trace = false
      expect(uaa.send(:scim).logger.level).to eq 1
    end
  end

  describe "#try_to_refresh_token!" do
    it "uses the refresh token to get a new access token" do
      uaa.send(:token_issuer).should_receive(:refresh_token_grant).with(uaa.token.refresh_token) do
        CF::UAA::TokenInfo.new(
          :token_type => "bearer",
          :access_token => "refreshed-token",
          :refresh_token => "some-refresh-token")
      end

      uaa.try_to_refresh_token!
      expect(uaa.token.auth_header).to eq "bearer refreshed-token"
      expect(uaa.token.refresh_token).to eq "some-refresh-token"
    end

    context "when the refresh token has expired" do
      it "returns the current token" do
        uaa.send(:token_issuer).should_receive(:refresh_token_grant) do
          raise CF::UAA::TargetError.new
        end

        expect {
          uaa.try_to_refresh_token!
        }.to_not change { uaa.token }
      end
    end
  end
end
