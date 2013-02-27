require 'spec_helper'

describe CcApiStub::Organizations do
  let(:client) { CFoundry::V2::Client.new }

  describe '.succeed_to_create' do
    it 'stubs creation of an organization' do
      CcApiStub::Organizations.succeed_to_create

      org = client.organization
      org.create!.should be_true
      org.guid.should == 'created-organization-id-1'
    end
  end

  describe '.summary_fixture' do
    it 'returns the fake org' do
      CcApiStub::Organizations.summary_fixture.should be_a(Hash)
    end
  end

  describe '.fail_to_find' do
    it 'fails to find the org' do
      guid = 'organization-id-1'
      CcApiStub::Organizations.fail_to_find(guid)
      client.organization(guid).exists?.should be_false
    end
  end

  describe '.succeed_to_load_summary' do
    it 'stubs loading the organization summary' do
      CcApiStub::Organizations.succeed_to_load_summary

      org = client.organization('organization-id-1')
      org.summarize!
      org.spaces[0].should be_a(CFoundry::V2::Space)
    end
  end

  describe '.succeed_to_search' do
    it 'stubs searching' do
      org_name = 'yoda'
      CcApiStub::Organizations.succeed_to_search(org_name)

      org = client.organization_by_name(org_name)
      org.guid.should == 'organization-id-1'
    end
  end

  describe '.succeed_to_search_none' do
    it 'stubs searching' do
      org_name = 'yoda'
      CcApiStub::Organizations.succeed_to_search_none

      org = client.organization_by_name(org_name)
      org.should be_nil
    end
  end

  describe '.domains_fixture' do
    it 'returns the fake domain' do
      CcApiStub::Organizations.domains_fixture.should be_a(Hash)
    end
  end

  describe '.domains_fixture_hash' do
    it 'returns the fake domain' do
      fixture = CcApiStub::Organizations.domain_fixture_hash
      fixture.should be_a(Hash)
      fixture.should == fixture.symbolize_keys
    end
  end

  describe '.succeed_to_load_domains' do
    it 'stubs domain loading' do
      CcApiStub::Organizations.succeed_to_load_domains
      org = client.organization('organization-id-1')
      org.domains[0].should be_a(CFoundry::V2::Domain)
    end
  end

  describe '.users_fixture' do
    it "returns the fake users" do
      CcApiStub::Organizations.users_fixture.should be_a(Hash)
    end
  end

  describe '.user_fixture_hash' do
    it 'returns the fake user' do
      fixture = CcApiStub::Organizations.user_fixture_hash
      fixture.should be_a(Hash)
      fixture.should == fixture.symbolize_keys
    end
  end

  describe '.succeed_to_load_users' do
    it 'stubs users loading' do
      CcApiStub::Organizations.succeed_to_load_users
      org = client.organization('organization-id-1')
      org.users[0].should be_a(CFoundry::V2::User)
    end
  end
end
