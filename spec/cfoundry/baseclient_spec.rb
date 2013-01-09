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

    context 'when an HTTPNotFound error occurs' do
      before {

        stub_request(:get, 'https://api.cloudfoundry.com/foo').to_return :status => 404,
        :body => "NOT FOUND"
      }

      it 'raises the correct error' do
        expect {subject}.to raise_error CFoundry::NotFound, "404: NOT FOUND"
      end
    end


    context 'when an HTTPForbidden error occurs' do
      before {
        stub_request(:get, 'https://api.cloudfoundry.com/foo').to_return :status => 403,
          :body => "NONE SHALL PASS"
      }

      it 'raises the correct error' do
        expect {subject}.to raise_error CFoundry::Denied, "403: NONE SHALL PASS"
      end
    end

    context "when any other type of error occurs" do
      before {
        stub_request(:get, 'https://api.cloudfoundry.com/foo').to_return :status => 411,
          :body => "NOT LONG ENOUGH"
      }

      it 'raises the correct error' do
        expect {subject}.to raise_error CFoundry::BadResponse, "411: NOT LONG ENOUGH"
      end
    end
  end
end
