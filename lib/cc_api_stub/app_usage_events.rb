module CcApiStub
  module AppUsageEvents
    extend Helper

    private

    def self.collection_endpoint
      %r{/v2/app_usage_events}
    end
  end
end
