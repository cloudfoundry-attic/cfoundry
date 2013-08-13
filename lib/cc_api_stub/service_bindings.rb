module CcApiStub
  module ServiceBindings
    extend Helper

    class << self
      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_service_binding")
        stub_post(collection_endpoint, {}, response(201, response_body))
      end

      private

      def object_endpoint(id = nil)
        %r{/v2/service_bindings/#{id}[^/]+$}
      end

      def collection_endpoint
        %r{/v2/service_bindings$}
      end
    end
  end
end
