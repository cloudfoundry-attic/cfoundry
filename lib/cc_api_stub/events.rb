module CcApiStub
  module Events
    extend Helper

    private

    def self.collection_endpoint
      %r{/v2/events}
    end
  end
end
