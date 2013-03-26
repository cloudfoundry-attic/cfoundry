module CcApiStub
  module Services
    extend Helper

    class << self
      def service_fixture_hash
        MultiJson.load(services_fixture["resources"].first.to_json, :symbolize_keys => true)
      end

      private

      def collection_endpoint
        %r{/v2/services\?inline-relations-depth=1}
      end

      def services_fixture
        Helper.load_fixtures("fake_cc_services")
      end
    end
  end
end
