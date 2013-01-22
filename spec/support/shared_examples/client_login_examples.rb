shared_examples_for 'client login' do
  let(:data) { {:foo => "bar"} }
  let(:token) { Base64.encode64(MultiJson.encode(:ignore => "hash") + MultiJson.encode(data) + "NONSENSE") }
  let(:uaa) { CFoundry::UAAClient.new }
  let(:email) { 'test@test.com' }
  let(:password) { 'secret' }

  subject { client.login(email, password) }

  before do
    stub(client.base).uaa { uaa }
    stub(uaa).authorize(email, password) { { :access_token => token } }
  end

  context 'when there is a UAA endpoint' do
    it 'returns a hash of data from the UAA endpoint' do
      expect(subject).to eq(:access_token => token, :access_token_data => data)
    end

    it 'saves the data as the token' do
      subject
      expect(client.token).to eq(:access_token => token, :access_token_data => data)
    end
  end

  context 'when there is non UAA endpoint (i.e. the system is a legacy one)' do
    before do
      stub(client.base).uaa { nil }
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