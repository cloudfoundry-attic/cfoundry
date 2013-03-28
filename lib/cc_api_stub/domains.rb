module CcApiStub
  module Domains
    extend Helper

    class << self
      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_created_domain")
        stub_post(%r{/v2/domains/?(\?.+)?$}, {}, response(201, response_body))
      end

      def succeed_to_delete
        stub_delete(%r{/v2/domains/[^/\?]+$}, {}, response(200))
      end

      def succeed_to_load_spaces
        response_body = Helper.load_fixtures("fake_cc_domain_spaces")
        stub_get(%r{/v2/domains/[^/]+/spaces.*$}, {}, response(200, response_body))
      end

      def succeed_to_add_space
        response_body = Helper.load_fixtures("fake_cc_created_domain")
        stub_put(%r{/v2/domains/[^/]+/spaces/[^/]+$}, {}, response(201, response_body))
      end

      private

      def object_endpoint
        %r{/v2/domains/[^/]+$}
      end
    end
  end
end
