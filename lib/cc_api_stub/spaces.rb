module CcApiStub
  module Spaces
    extend Helper

    class << self
      def succeed_to_load(options={})
        response_body = Helper.load_fixtures(options.delete(:fixture) || "fake_cc_#{object_name}", options)
        stub_get(object_endpoint, {}, response(200, response_body))
      end

      def succeed_to_create
        response_body = Helper.load_fixtures("fake_cc_created_space")
        stub_post(collection_endpoint, {}, response(201, response_body))
      end

      def summary_fixture
        Helper.load_fixtures("fake_cc_space_summary")
      end

      def succeed_to_load_summary(options={})
        response_body = summary_fixture
        response_body["services"] = [] if options.delete(:no_services)
        stub_get(%r{/v2/spaces/[^/]+/summary$}, {}, response(200, response_body))
      end

      def space_fixture_hash
        {
          :metadata => {
            :guid => "space-id-1",
            :url => "/v2/spaces/space-id-1"
          },
          :entity => {
            :name => "space-name-1"
          }
        }
      end

      private

      def collection_endpoint
        %r{/v2/spaces$}
      end

      def object_endpoint
        %r{/v2/spaces/[^/]+$}
      end
    end
  end
end
