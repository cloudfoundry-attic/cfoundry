module CcApiStub
  module Runtimes
    extend Helper

    class << self
      def succeed_to_load
        response_body = Helper.load_fixtures("fake_cc_runtimes")
        stub_get(collection_endpoint, {}, response(200, response_body))
      end

      def fail_to_load
        stub_get(collection_endpoint, {}, response(500))
      end

      private

      def collection_endpoint
        %r{/v2/runtimes\?inline-relations-depth=1$}
      end
    end
  end
end
