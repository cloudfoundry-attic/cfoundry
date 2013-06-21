shared_examples_for 'client login prompts' do
  let(:uaa) { CFoundry::UAAClient.new }
  let(:prompts) do
    {
      :user_id => ["text", "User ID"],
      :pin => ["password", "Your 8-digit Pin #"]
    }
  end

  before do
    client.base.stub(:uaa) { uaa }
    uaa.stub(:prompts) { prompts }
  end

  subject { client.login_prompts }

  it 'returns the prompts provided by UAA' do
    expect(subject).to eq(prompts)
  end
end

shared_examples_for 'client login' do
  let(:email) { 'test@test.com' }
  let(:password) { 'secret' }
  let(:uaa) { CFoundry::UAAClient.new }
  let(:access_token) { "some-access-token" }
  let(:token_info) { CF::UAA::TokenInfo.new({ :access_token => access_token, :token_type => "bearer" }) }

  before do
    client.base.stub(:uaa) { uaa }
    uaa.stub(:authorize).with(email, password) { token_info }
  end

  subject { client.login(email, password) }

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
