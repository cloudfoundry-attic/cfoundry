module CcApiStub
  module Spaces
    extend Helper

    class << self
      def succeed_to_load(options={})
        response_body = Helper.load_fixtures(options.delete(:fixture) || "fake_cc_#{object_name}", options)
        stub_get(object_endpoint(options[:id]), {}, response(200, response_body))
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

      def succeed_to_load_apps(options={})
        response = response_from_options(options.reverse_merge!({:fixture => "fake_cc_space_apps"}))
        stub_get(%r{/v2/spaces/[^/]+/apps\?inline-relations-depth=1}, {}, response(200, response))
      end

      def fail_to_find(space_id)
        stub_get(%r{/v2/spaces/#{space_id}}, {}, response(404, {:code => 40004, :description => "The app space could not be found:"}))
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

      def object_endpoint(id = nil)
        %r{/v2/spaces/#{id}[^/]+$}
      end
    end
  end
end
