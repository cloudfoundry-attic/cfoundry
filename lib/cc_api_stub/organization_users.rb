module CcApiStub
  module OrganizationUsers
    extend Helper

    class << self
      def succeed_to_delete
        stub_delete(object_endpoint, {}, response(200, ""))
      end

      def fail_to_delete
        stub_delete(object_endpoint, {}, response(500))
      end

      private

      def object_endpoint
        %r{/v2/organizations/[^/]+/users/[^/]+$}
      end
    end
  end
end
