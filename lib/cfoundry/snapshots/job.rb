module CFoundry::Snapshots
  class Job
    def initialize(manifest, client)
      @manifest = manifest
      @client = client
    end

    def guid
      @manifest[:job_id]
    end

    def description
      @manifest[:description]
    end

    def status
      @manifest[:status]
    end

    def start_time
      DateTime.parse(@manifest[:start_time])
    end

    def result
      @manifest[:result]
    end

    def wait(options = {})
      seconds = options[:interval] || 1
      timeout = options[:timeout] || 60

      Timeout.timeout(timeout) do
        until status == "completed"
          sleep seconds
          @manifest = @client.job(guid)
        end
      end

      nil
    end
  end
end
