module CcApiStub
  module Applications
    extend Helper

    class << self
      def succeed_to_load(options={})
        response_body = Helper.load_fixtures(options.delete(:fixture) || "fake_cc_#{object_name}", options)
        stub_get(object_endpoint(options[:id]), {}, response(200, response_body))
      end

      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_created_application")
        stub_post(%r{/v2/apps$}, nil, response(201, response_body))
      end

      def succeed_to_update(options={})
        response_body = Helper.load_fixtures(:fake_cc_application, options)
        stub_put(object_endpoint(options[:id]), nil, response(200, response_body))
      end

      def succeed_to_map_route
        stub_put(%r{/v2/apps/[^/]+/routes/[^/]+$}, {}, response(201, {}))
      end

      def succeed_to_load_stats
        response_body = Helper.load_fixtures("fake_cc_stats")
        stub_get(%r{/v2/apps/[^/]+/stats$}, {}, response(200, response_body))
      end

      def summary_fixture
        Helper.load_fixtures("fake_cc_application_summary")
      end

      def succeed_to_load_summary(options={})
        response = summary_fixture
        response["state"] = options[:state] if options.has_key?(:state)
        response["routes"] = options[:routes] if options.has_key?(:routes)
        stub_get(%r{/v2/apps/[^/]+/summary$}, {}, response(200, response))
      end

      def succeed_to_load_service_bindings
        response_body = Helper.load_fixtures("fake_cc_service_bindings")
        stub_get(%r{/v2/apps/[^/]+/service_bindings/?(?:\?.+)?$}, {}, response(200, response_body))
      end

      private

      def object_endpoint(id = nil)
        %r{/v2/apps/#{id}[^/]+$}
      end
    end
  end
end
