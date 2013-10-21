module CcApiStub
  module SpaceUsers
    extend Helper

    class << self
      def succeed_to_delete(options = {})
        if options.has_key? :roles
          options[:roles].each do |role|
            stub_delete(object_endpoint(options[:id], role.to_s.pluralize), {}, response(200, ""))
          end
        end

        stub_delete(object_endpoint(options[:id]), {}, response(200, ""))
      end

      def fail_to_delete(options = {})
        stub_delete(object_endpoint(options[:id]), {}, response(500))
      end

      private

      def object_endpoint(id = nil, role="users")
        %r{/v2/spaces/[^/]+/#{role}/#{id}[^/]+$}
      end
    end
  end
end
