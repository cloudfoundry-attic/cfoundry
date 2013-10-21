require 'spec_helper'
require 'net/http'
require 'uri'

describe CcApiStub::Organizations do
  let(:client) { build(:client) }

  describe ".succeed_to_create" do
    let(:url) { "http://example.com/v2/organizations/" }
    subject { CcApiStub::Organizations.succeed_to_create }

    it_behaves_like "a stubbed post request"
  end


  describe '.summary_fixture' do
    it 'returns the fake org' do
      CcApiStub::Organizations.summary_fixture.should be_a(Hash)
    end
  end

  describe '.fail_to_find' do
    let(:url) { "http://example.com/v2/organizations/9234" }
    subject { CcApiStub::Organizations.fail_to_find(9234) }

    it_behaves_like "a stubbed get request", :code => 404
  end

  describe '.succeed_to_load_summary' do
    let(:url) { "http://example.com/v2/organizations/9234/summary" }
    subject { CcApiStub::Organizations.succeed_to_load_summary }

    it_behaves_like "a stubbed get request"

    context "when passed a no_spaces option" do
      subject { CcApiStub::Organizations.succeed_to_load_summary(:no_spaces => true) }

      it_behaves_like "a stubbed get request", :including_json => { "spaces" => [] }
    end
  end

  describe '.succeed_to_search' do
    let(:url) { "http://example.com/v2/organizations?inline-relations-depth=1&q=name:orgname" }
    subject { CcApiStub::Organizations.succeed_to_search("orgname") }

    it_behaves_like "a stubbed get request"
  end

  describe '.succeed_to_search_none' do
    let(:url) { "http://example.com/v2/organizations?inline-relations-depth=1&q=name:orgname" }
    subject { CcApiStub::Organizations.succeed_to_search_none }

    it_behaves_like "a stubbed get request"
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
    let(:url) { "http://example.com/v2/organizations/3434/domains?inline-relations-depth=1" }
    subject { CcApiStub::Organizations.succeed_to_load_domains }

    it_behaves_like "a stubbed get request"
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
    let(:url) { "http://example.com/v2/organizations/2342/users?inline-relations-depth=1" }
    subject { CcApiStub::Organizations.succeed_to_load_users }

    it_behaves_like "a stubbed get request"
  end

  describe '.spaces_fixture' do
    it "returns the fake spaces" do
      CcApiStub::Organizations.spaces_fixture.should be_a(Hash)
    end
  end

  describe '.space_fixture_hash' do
    it 'returns the fake space' do
      fixture = CcApiStub::Organizations.space_fixture_hash
      fixture.should be_a(Hash)
      fixture.should == fixture.symbolize_keys
    end
  end

  describe '.succeed_to_load_spaces' do
    let(:url) { "http://example.com/v2/organizations/2342/spaces?inline-relations-depth=1" }
    subject { CcApiStub::Organizations.succeed_to_load_spaces }

    it_behaves_like "a stubbed get request"
  end
end
