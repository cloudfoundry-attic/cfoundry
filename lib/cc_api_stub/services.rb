module CcApiStub
  module Services
    extend Helper

    class << self
      def succeed_to_load
        stub_get(collection_endpoint, {}, response(200, services_fixture))
      end

      def service_fixture_hash
        MultiJson.load(services_fixture["resources"].first.to_json, :symbolize_keys => true)
      end

      private

      def collection_endpoint
        %r{/v2/services\?inline-relations-depth=1}
      end

      def services_fixture
        Helper.load_fixtures("fake_cc_service_types")
      end
    end
  end
end
