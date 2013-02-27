module CcApiStub
  module Routes
    extend Helper

    class << self
      def succeed_to_load_none
        stub_get(collection_endpoint, {}, response(200, {:resources => []}))
      end

      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_created_route")
        stub_post(collection_endpoint, {}, response(201, response_body))
      end

      private

      def collection_endpoint
        %r{/v2/routes/?.*$}
      end

      def object_endpoint
        %r{/v2/routes/[^/]+$}
      end
    end
  end
end
