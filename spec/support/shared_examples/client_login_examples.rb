shared_examples_for 'client login prompts' do
  before do
    stub(client.base).uaa { uaa }
  end

  subject { client.login_prompts }

  context 'when there is a UAA endpoint' do
    let(:uaa) { CFoundry::UAAClient.new }

    let(:prompts) do
      {
        :user_id => ["text", "User ID"],
        :pin => ["password", "Your 8-digit Pin #"]
      }
    end

    before do
      stub(uaa).prompts { prompts }
    end

    it 'returns the prompts provided by UAA' do
      expect(subject).to eq(prompts)
    end
  end

  context 'when there is no UAA endpoint (a legacy system)' do
    let(:uaa) { nil}

    it 'prompts for a username and password' do
      expect(subject).to eq(
        :username => %w(text Email),
        :password => %w(password Password)
      )
    end
  end
end

shared_examples_for 'client login' do
  let(:email) { 'test@test.com' }
  let(:password) { 'secret' }
  let(:uaa) { CFoundry::UAAClient.new }
  let(:access_token) { "some-access-token" }
  let(:token_info) { CF::UAA::TokenInfo.new({ :access_token => access_token, :token_type => "bearer" }) }

  before do
    stub(client.base).uaa { uaa }
    stub(uaa).authorize(email, password) { token_info }
  end

  subject { client.login(email, password) }

  context 'when there is a UAA endpoint' do
    it 'returns a UAA token' do
      expect(subject).to be_a(CFoundry::AuthToken)
      expect(subject.auth_header).to eq("bearer #{access_token}")
    end

    it 'saves the data as the token' do
      subject
      expect(client.token).to be_a(CFoundry::AuthToken)
      expect(client.token.auth_header).to eq("bearer #{access_token}")
    end
  end

  context 'when there is no UAA endpoint (a legacy system)' do
    let(:uaa) { nil }
    let(:token_header) { "bearer some-base64" }

    before do
      stub(client.base).create_token { {:token => token_header} }
    end

    it 'returns the token from the legacy `tokens` endpoint on cloud controller' do
      expect(subject).to be_a(CFoundry::AuthToken)
      expect(subject.auth_header).to eq(token_header)
    end

    it 'saves the data as the token' do
      subject
      expect(client.base.token).to be_a(CFoundry::AuthToken)
      expect(client.base.token.auth_header).to eq(token_header)
    end
  end
end