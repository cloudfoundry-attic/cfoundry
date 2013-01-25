module CFoundry::Snapshots
  class Snapshot
    def initialize(manifest, client)
      @manifest = manifest
      @client = client
    end

    def guid
      @manifest[:snapshot_id]
    end

    def name
      @manifest[:name]
    end

    def size
      @manifest[:size]
    end

    def created_at
      DateTime.parse(@manifest[:date])
    end
  end
end
