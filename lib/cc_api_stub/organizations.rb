module CcApiStub
  module Organizations
    extend Helper

    class << self
      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_created_organization")
        stub_post(collection_endpoint, {}, response(201, response_body))
      end

      def summary_fixture
        Helper.load_fixtures("fake_cc_organization_summary")
      end

      def fail_to_find(org_id)
        stub_get(%r{/v2/organizations/#{org_id}}, {}, response(404, {:code => 30003, :description => "The organization could not be found"}))
      end

      def succeed_to_load_summary(options={})
        response_body = summary_fixture
        response_body["spaces"] = [] if options[:no_spaces]
        stub_get(%r{/v2/organizations/[^/]+/summary$}, {}, response(200, response_body))
      end

      def succeed_to_search(name)
        response_body = Helper.load_fixtures("fake_cc_organization_search")
        stub_get(%r{/v2/organizations\?inline-relations-depth=1&q=name:#{name}$}, {}, response(200, response_body))
      end

      def succeed_to_search_none
        response_body = Helper.load_fixtures("fake_cc_empty_search")
        stub_get(%r{/v2/organizations\?inline-relations-depth=1&q=name:.*$}, {}, response(200, response_body))
      end

      def domains_fixture
        Helper.load_fixtures("fake_cc_organization_domains")
      end

      def domain_fixture_hash
        MultiJson.load(domains_fixture["resources"].first.to_json, :symbolize_keys => true)
      end

      def succeed_to_load_domains
        stub_get(%r{/v2/organizations/[^/]+/domains\?inline-relations-depth=1}, {}, response(200, domains_fixture))
      end

      def users_fixture
        Helper.load_fixtures("fake_cc_organization_users")
      end

      def user_fixture_hash
        MultiJson.load(users_fixture["resources"].first.to_json, :symbolize_keys => true)
      end

      def succeed_to_load_users
        stub_get(%r{/v2/organizations/[^\/]+/users\?inline-relations-depth=1}, {}, response(200, users_fixture))
      end

      def spaces_fixture
        Helper.load_fixtures("fake_cc_organization_spaces")
      end

      def space_fixture_hash
        MultiJson.load(spaces_fixture["resources"].first.to_json, :symbolize_keys => true)
      end

      def succeed_to_load_spaces
        stub_get(%r{/v2/organizations/[^\/]+/spaces\?inline-relations-depth=1}, {}, response(200, spaces_fixture))
      end

      private

      def object_endpoint(id = nil)
        %r{/v2/organizations/#{id}[^/]+$}
      end

      def collection_endpoint
        %r{/v2/organizations\/?(\?.+)?$}
      end
    end
  end
end
