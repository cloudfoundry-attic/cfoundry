require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Routes do
  let(:url) { "http://example.com/v2/routes/" }

  describe ".succeed_to_load_none" do
    subject { CcApiStub::Routes.succeed_to_load_none }

    it_behaves_like "a stubbed get request", :including_json => { "resources" => [] }
  end

  describe ".succeed_to_create" do
    subject { CcApiStub::Routes.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end
end