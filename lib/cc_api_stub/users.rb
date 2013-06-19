module CcApiStub
  module Users
    extend Helper

    class << self
      def succeed_to_load(options={})
        response_body = Helper.load_fixtures(options[:fixture] || "fake_cc_user")
        response_body["metadata"]["guid"] = options[:id] || "user-id-1"

        if options[:no_organizations]
          response_body["entity"]["organizations"] = []
        else
          def space(space_id) {"metadata" => { "guid" => space_id }, "entity" => {}} end

          organization = response_body["entity"]["organizations"].first
          organization["metadata"]["guid"] = options[:organization_id] || "organization-id-1"
          organization["entity"]["spaces"] = [] if options[:no_spaces]

          permissions = options[:permissions] || [:organization_manager]

          response_body["entity"]["managed_organizations"] << organization if permissions.include?(:organization_manager)
          response_body["entity"]["billing_managed_organizations"] << organization if permissions.include?(:organization_billing_manager)
          response_body["entity"]["audited_organizations"] << organization if permissions.include?(:organization_auditor)

          unless options[:no_spaces]
            space = space("space-id-1")
            response_body["entity"]["spaces"] << space         if permissions.include?(:space_developer)
            response_body["entity"]["managed_spaces"] << space if permissions.include?(:space_manager)
            response_body["entity"]["audited_spaces"] << space if permissions.include?(:space_auditor)

            space2 = space("space-id-2")
            response_body["entity"]["spaces"] << space2         if permissions.include?(:space2_developer)
            response_body["entity"]["managed_spaces"] << space2 if permissions.include?(:space2_manager)
            response_body["entity"]["audited_spaces"] << space2 if permissions.include?(:space2_auditor)
          end
        end

        stub_get(%r{/v2/users/[^/]+\?inline-relations-depth=2$}, {}, response(200, response_body))
        stub_get(%r{/v2/users/[^/]+/summary(\?inline-relations-depth=\d)?$}, {}, response(200, response_body))
      end

      def fail_to_find
        stub_get(object_endpoint, {}, response(404, {:code => 20003, :description => "The user could not be found"}))
      end

      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_created_user")
        stub_post(collection_endpoint, {}, response(201, response_body))
      end

      def fail_to_create
        CcApiStub::Helper.fail_request(:post, 500, {}, /users/)
      end

      def succeed_to_replace_permissions
        stub_put(object_endpoint, {}, response(200, ""))
      end

      def fail_to_replace_permissions
        stub_put(object_endpoint, {}, response(500))
      end

      def organizations_fixture
        Helper.load_fixtures("fake_cc_user")["entity"]["organizations"]
      end

      def organization_fixture_hash(options={})
        fixture = organizations_fixture.first
        fixture["entity"].delete("spaces") if options[:no_spaces]
        fixture["entity"].delete("managers") if options[:no_managers]
        MultiJson.load(fixture.to_json, :symbolize_keys => true)
      end

      private

      def collection_endpoint
        %r{/v2/users$}
      end

      def object_endpoint
        %r{/v2/users/[^/]+(/summary)?}
      end
    end
  end
end
