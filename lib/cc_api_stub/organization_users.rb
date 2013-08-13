module CcApiStub
  module OrganizationUsers
    extend Helper

    class << self
      def succeed_to_delete(options = {})
        stub_delete(object_endpoint(options[:id]), {}, response(200, ""))
      end

      def fail_to_delete(options = {})
        stub_delete(object_endpoint(options[:id]), {}, response(500))
      end

      private

      def object_endpoint(id = nil)
        %r{/v2/organizations/[^/]+/users/#{id}[^/]+$}
      end
    end
  end
end
