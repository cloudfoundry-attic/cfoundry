module CFoundry::V2
  class AppInstance
    attr_reader :id

    def self.for_app(name, guid, client)
      client.base.instances(guid).collect do |i, m|
        AppInstance.new(name, guid, i.to_s, client, m)
      end
    end

    def initialize(app_name, app_guid, id, client, manifest = {})
      @app_name = app_name
      @app_guid = app_guid
      @id = id
      @client = client
      @manifest = manifest
    end

    def inspect
      "#<App::Instance '#{@app_name}' \##@id>"
    end

    def state
      @manifest[:state]
    end

    alias_method :status, :state

    def since
      if since = @manifest[:since]
        Time.at(@manifest[:since])
      end
    end

    def debugger
      return unless @manifest[:debug_ip] and @manifest[:debug_port]

      {:ip => @manifest[:debug_ip],
        :port => @manifest[:debug_port]
      }
    end

    def console
      return unless @manifest[:console_ip] and @manifest[:console_port]

      {:ip => @manifest[:console_ip],
        :port => @manifest[:console_port]
      }
    end

    def healthy?
      case state
      when "STARTING", "RUNNING"
        true
      when "DOWN", "FLAPPING"
        false
      end
    end

    def files(*path)
      @client.base.files(@app_guid, @id, *path).split("\n").collect do |entry|
        path + [entry.split(/\s+/, 2)[0]]
      end
    end

    def file(*path)
      @client.base.files(@app_guid, @id, *path)
    end

    def stream_file(*path, &blk)
      @client.base.stream_file(@app_guid, @id, *path, &blk)
    end
  end
end
