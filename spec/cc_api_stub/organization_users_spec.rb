require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::OrganizationUsers do
  let(:url) { "http://example.com/v2/organizations/123/users/94087" }

  describe ".succeed_to_delete" do
    subject { CcApiStub::OrganizationUsers.succeed_to_delete }

    it_behaves_like "a stubbed delete request"

    context "when the :roles option is provided" do
      let(:roles) { [:user, :managers, :auditor] }
      it "deletes the user from each specified role" do
        CcApiStub::OrganizationUsers.succeed_to_delete(roles: roles)
        roles.each do |role|
          url = "http://example.com/v2/organizations/123/#{role.to_s.pluralize}/94087"
          uri = URI.parse(url)
          Net::HTTP.start(uri.host, uri.port) do |http|
            request = Net::HTTP::Delete.new(url)
            response = http.request(request)
            check_response(response, code: 200, ignore_response: true)
          end
        end
      end
    end
  end

  describe ".fail_to_delete" do
    subject { CcApiStub::OrganizationUsers.fail_to_delete }

    it_behaves_like "a stubbed delete request", :code => 500, :ignore_response => true
  end
end
