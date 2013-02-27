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
    end
  end
end
