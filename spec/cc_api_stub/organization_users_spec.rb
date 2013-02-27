require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::OrganizationUsers do
  let(:url) { "http://example.com/v2/organizations/123/users/94087" }

  describe ".succeed_to_delete" do
    subject { CcApiStub::OrganizationUsers.succeed_to_delete }

    it_behaves_like "a stubbed delete request"
  end

  describe ".fail_to_delete" do
    subject { CcApiStub::OrganizationUsers.fail_to_delete }

    it_behaves_like "a stubbed delete request", :code => 500, :ignore_response => true
  end
end