require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Services do
  describe '.service_fixture_hash' do
    it 'returns the fake services' do
      CcApiStub::Services.service_fixture_hash.should be_a(Hash)
    end
  end
end
