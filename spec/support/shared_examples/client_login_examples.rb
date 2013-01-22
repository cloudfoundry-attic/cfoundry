shared_examples_for 'client login' do
  let(:data) { {:foo => "bar"} }
  let(:token) { Base64.encode64(MultiJson.encode(:ignore => "hash") + MultiJson.encode(data) + "NONSENSE") }
  let(:uaa) { CFoundry::UAAClient.new }
  let(:email) { 'test@test.com' }
  let(:password) { 'secret' }

  before do
    stub(client.base).uaa { uaa }
    stub(uaa).authorize(email, password) { { :access_token => token } }
  end

  describe "#login_prompts" do
    subject { client.login_prompts }

    context 'when there is a UAA endpoint' do
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

  describe "#login" do
    subject { client.login(email, password) }

    context 'when there is a UAA endpoint' do
      it 'returns a hash of data from the UAA endpoint' do
        expect(subject).to eq(:access_token => token, :access_token_data => data)
      end

      it 'saves the data as the token' do
        subject
        expect(client.token).to eq(:access_token => token, :access_token_data => data)
      end
    end

    context 'when there is no UAA endpoint (a legacy system)' do
      let(:uaa) { nil}

      before do
        stub(client.base).create_token { {:token => token} }
      end

      it 'returns the token from the legacy `tokens` endpoint on cloud controller' do
        expect(subject).to eq(:access_token => token, :access_token_data => data)
      end

      it 'saves the data as the token' do
        subject
        expect(client.token).to eq(:access_token => token, :access_token_data => data)
      end
    end

    context 'when there is non UAA endpoint with no data encoded in the access token' do
      before do
        stub(client.base).uaa { nil }
        stub(client.base).create_token { {:token => token} }
      end

      let(:token) { "NONSENSE" }

      it 'returns the token from the legacy `tokens` endpoint on cloud controller' do
        expect(subject).to eq(:access_token => token, :access_token_data => {})
      end

      it 'saves the data as the token' do
        subject
        expect(client.token).to eq(:access_token => token, :access_token_data => {})
      end
    end
  end
end