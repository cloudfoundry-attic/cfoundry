module CFoundry::V2
  class AppInstance
    attr_reader :app, :id

    def initialize(app, id, client, manifest = {})
      @app = app
      @id = id
      @client = client
      @manifest = manifest
    end

    def inspect
      "#<App::Instance '#{@app.name}' \##@id>"
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
      @client.base.files(@app.guid, @id, *path).split("\n").collect do |entry|
        path + [entry.split(/\s+/, 2)[0]]
      end
    end

    def file(*path)
      @client.base.files(@app.guid, @id, *path)
    end

    def stream_file(*path, &blk)
      @client.base.stream_file(@app.guid, @id, *path, &blk)
    end
  end
end
