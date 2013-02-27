module CcApiStub
  module Frameworks
    extend Helper

    class << self
      def succeed_to_load
        response_body = Helper.load_fixtures("fake_cc_frameworks")
        stub_get(collection_endpoint, {}, response(200, response_body))
      end

      def fail_to_load
        stub_get(collection_endpoint, {}, response(500))
      end

      private

      def collection_endpoint
        %r{/v2/frameworks\?inline-relations-depth=1$}
      end
    end
  end
end
