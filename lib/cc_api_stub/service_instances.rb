module CcApiStub
  module ServiceInstances
    extend Helper

    class << self
      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_created_service_instance")
        stub_post(collection_endpoint, {}, response(201, response_body))
      end

      private

      def object_endpoint
        %r{/v2/service_instances/[^/]+$}
      end

      def collection_endpoint
        %r{/v2/service_instances$}
      end
    end
  end
end
