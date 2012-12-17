require 'spec_helper'

describe CFoundry::BaseClient do
  let(:base) { CFoundry::BaseClient.new("https://api.cloudfoundry.com") }

  describe '#request_uri' do
    subject { base.request_uri URI.parse(base.target + "/foo"), Net::HTTP::Get }

    context 'when a timeout exception occurs' do
      before { stub_request(:get, 'https://api.cloudfoundry.com/foo').to_raise(::Timeout::Error) }

      it 'raises the correct error' do
        expect { subject }.to raise_error CFoundry::Timeout, "GET https://api.cloudfoundry.com/foo timed out"
      end
    end
  end
end
