require "tmpdir"
require "multi_json"

require "cfoundry/zip"
require "cfoundry/upload_helpers"
require "cfoundry/chatty_hash"

require "cfoundry/v2/model"

module CFoundry::V2
  # Class for representing a user's application on a given target (via
  # Client).
  #
  # Does not guarantee that the app exists; used for both app creation and
  # retrieval, as the attributes are all lazily retrieved. Setting attributes
  # does not perform any requests; use #update! to commit your changes.
  class App < Model
    include CFoundry::UploadHelpers

    attribute :name,             :string
    to_one    :space
    attribute :environment_json, :hash,    :default => {}
    attribute :memory,           :integer, :default => 256
    attribute :total_instances,  :integer, :default => 1, :at => :instances
    attribute :disk_quota,       :integer, :default => 256
    attribute :state,            :string,  :default => "STOPPED"
    attribute :command,          :string,  :default => nil
    attribute :console,          :boolean, :default => false
    attribute :buildpack,        :string,  :default => nil
    to_one    :stack,                      :default => nil
    attribute :debug,            :string,  :default => nil
    to_many   :service_bindings
    to_many   :routes
    to_many   :events, :as => :app_event

    scoped_to_space

    queryable_by :name, :space_guid, :organization_guid

    has_summary :urls => proc { |x| self.cache[:uris] = x },
      :running_instances => proc { |x|
        self.cache[:running_instances] = x
      },
      :instances => proc { |x|
        self.total_instances = x
      }

    private :environment_json

    def delete!(opts = {})
      super(opts.merge(:recursive => true))
    end

    def instances
      @client.base.instances(@guid).collect do |i, m|
        Instance.new(self, i.to_s, @client, m)
      end
    end

    def crashes
      @client.base.crashes(@guid).collect do |m|
        Instance.new(self, m[:instance], @client, m)
      end
    end

    def stats
      stats = {}

      @client.base.stats(@guid).each do |idx, info|
        stats[idx.to_s] = info
      end

      stats
    end

    def services
      service_bindings.collect(&:service_instance)
    end

    def env
      CFoundry::ChattyHash.new(
        method(:env=),
        stringify(environment_json))
    end

    def env=(x)
      self.environment_json = stringify(x.to_hash)
    end

    alias :debug_mode :debug

    def uris
      return @cache[:uris] if @cache[:uris]

      routes.collect do |r|
        "#{r.host}.#{r.domain.name}"
      end
    end
    alias :urls :uris

    def uris=(uris)
      raise CFoundry::Deprecated,
        "App#uris= is invalid against V2 APIs; use add/remove_route"
    end
    alias :urls= :uris=

    def uri
      if uris = @cache[:uris]
        return uris.first
      end

      if route = routes.first
        "#{route.host}.#{route.domain.name}"
      end
    end
    alias :url :uri

    def uri=(x)
      self.uris = [x]
    end
    alias :url= :uri=

    # Stop the application.
    def stop!
      self.state = "STOPPED"
      update!
    end

    # Start the application.
    def start!(async = false, &blk)
      self.state = "STARTED"
      update!(async, &blk)
    end

    # Restart the application.
    def restart!(async = false, &blk)
      stop!
      start!(async, &blk)
    end

    def update!(async = false)
      response = @client.base.update_app(@guid, @diff, async)

      yield response[:headers]["x-app-staging-log"] if block_given?

      @manifest = @client.base.send(:parse_json, response[:body])

      @diff.clear

      true
    end

    def stream_update_log(log_url)
      offset = 0

      while true
        begin
          @client.stream_url(log_url + "&tail&tail_offset=#{offset}") do |out|
            offset += out.size
            yield out
          end
        rescue Timeout::Error
        end
      end
    rescue CFoundry::APIError
    end

    # Determine application health.
    #
    # If all instances are running, returns "RUNNING". If only some are
    # started, returns the precentage of them that are healthy.
    #
    # Otherwise, returns application's status.
    def health
      if state == "STARTED"
        healthy_count = running_instances
        expected = total_instances

        if expected > 0
          ratio = healthy_count / expected.to_f
          if ratio == 1.0
            "RUNNING"
          else
            "#{(ratio * 100).to_i}%"
          end
        else
          "N/A"
        end
      else
        state
      end
    end

    def running_instances
      return @cache[:running_instances] if @cache[:running_instances]

      running = 0

      instances.each do |i|
        running += 1 if i.state == "RUNNING"
      end

      running
    end

    # Check that all application instances are running.
    def healthy?
      # invalidate cache so the check is fresh
      invalidate!
      health == "RUNNING"
    end
    alias_method :running?, :healthy?

    # Is the application stopped?
    def stopped?
      state == "STOPPED"
    end

    # Is the application started?
    #
    # Note that this does not imply that all instances are running. See
    # #healthy?
    def started?
      state == "STARTED"
    end

    # Bind services to application.
    def bind(*instances)
      instances.each do |i|
        binding = @client.service_binding
        binding.app = self
        binding.service_instance = i
        binding.create!
      end

      self
    end

    # Unbind services from application.
    def unbind(*instances)
      service_bindings.each do |b|
        if instances.include? b.service_instance
          b.delete!
        end
      end

      self
    end

    def binds?(instance)
      service_bindings.any? { |b|
        b.service_instance == instance
      }
    end

    def files(*path)
      Instance.new(self, "0", @client).files(*path)
    end

    def file(*path)
      Instance.new(self, "0", @client).file(*path)
    end

    def stream_file(*path, &blk)
      Instance.new(self, "0", @client).stream_file(*path, &blk)
    end

    private

    def stringify(hash)
      new = {}

      hash.each do |k, v|
        new[k.to_s] = v.to_s
      end

      new
    end

    class Instance
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

        { :ip => @manifest[:debug_ip],
          :port => @manifest[:debug_port]
        }
      end

      def console
        return unless @manifest[:console_ip] and @manifest[:console_port]

        { :ip => @manifest[:console_ip],
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
end
