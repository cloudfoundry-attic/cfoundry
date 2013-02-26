require "cfoundry/upload_helpers"
require "cfoundry/chatty_hash"

require "cfoundry/v1/model"

module CFoundry::V1
  class App < Model
    include CFoundry::UploadHelpers

    attribute :name,      :string,   :guid => true
    attribute :instances, :integer
    attribute :state,     :string
    attribute :created,   :integer,  :at => [:meta, :created], :read_only => true
    attribute :version,   :integer,  :at => [:meta, :version], :read_only => true
    attribute :framework, :string,   :at => [:staging, :model]
    attribute :runtime,   :string,   :at => [:staging, :stack]
    attribute :command,   :string,   :at => [:staging, :command]
    attribute :memory,    :integer,  :at => [:resources, :memory]
    attribute :disk,      :integer,  :at => [:resources, :disk]
    attribute :fds,       :integer,  :at => [:resources, :fds]
    attribute :env,       [:string], :default => []
    attribute :uris,      [:string], :default => []
    attribute :services,  [:string], :default => []

    attribute :console, :boolean, :default => false,
              :read => [:meta, :console], :write => :console

    attribute :debug, :string, :default => nil, :read => [:meta, :debug],
              :write => :debug

    attribute :running_instances, :integer, :read => :runningInstances,
              :read_only => true


    define_client_methods


    alias_method :total_instances, :instances
    alias_method :total_instances=, :instances=

    alias_method :debug_mode, :debug
    alias_method :debug_mode=, :debug=

    alias_method :framework_name, :framework
    alias_method :framework_name=, :framework=

    alias_method :runtime_name, :runtime
    alias_method :runtime_name=, :runtime=

    alias_method :service_names, :services
    alias_method :service_names=, :services=

    alias_method :status, :state
    alias_method :status=, :state=

    alias_method :urls, :uris
    alias_method :urls=, :uris=

    alias_method :env_array, :env
    alias_method :env_array=, :env=

    def framework
      @client.framework(framework_name)
    end

    def framework=(obj)
      set_named(:framework, obj)
    end

    def runtime
      @client.runtime(runtime_name)
    end

    def runtime=(obj)
      set_named(:runtime, obj)
    end

    def services
      service_names.collect { |name| @client.service_instance(name) }
    end

    def services=(objs)
      set_many_named(:service, objs)
    end


    # Retrieve all of the instances of the app, as Instance objects.
    def instances
      @client.base.instances(@guid).collect do |m|
        Instance.new(self, m[:index].to_s, @client, m)
      end
    end

    # Retrieve crashed instances
    def crashes
      @client.base.crashes(@guid).collect do |i|
        Instance.new(self, i[:instance].to_s, @client, i)
      end
    end

    # Retrieve application statistics, e.g. CPU load and memory usage.
    def stats
      stats = {}

      @client.base.stats(@guid).each do |idx, info|
        stats[idx.to_s] = info
      end

      stats
    end

    # Stop the application.
    def stop!
      self.state = "STOPPED"
      update!
    end

    # Start the application.
    def start!(async = false)
      self.state = "STARTED"
      update!
    end

    # Restart the application.
    def restart!(async = false)
      stop!
      start!
    end

    def update!(async = false)
      super()
    end

    # Determine application health.
    #
    # If all instances are running, returns "RUNNING". If only some are
    # started, returns the precentage of them that are healthy.
    #
    # Otherwise, returns application's status.
    def health
      s = state
      if s == "STARTED"
        healthy_count = running_instances
        expected = total_instances

        if healthy_count && expected > 0
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
        s
      end
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


    # Shortcut for uris[0]
    def uri
      uris[0]
    end

    # Shortcut for uris = [x]
    def uri=(x)
      self.uris = [x]
    end

    alias_method :url, :uri
    alias_method :url=, :uri=

    def env
      e = env_array || []

      env = {}
      e.each do |pair|
        name, val = pair.split("=", 2)
        env[name] = val
      end

      CFoundry::ChattyHash.new(method(:env=), env)
    end

    def env=(hash)
      unless hash.is_a?(Array)
        hash = hash.collect { |k, v| "#{k}=#{v}" }
      end

      self.env_array = hash
    end

    def services
      service_names.collect do |name|
        @client.service_instance(name)
      end
    end

    def services=(instances)
      self.service_names = instances.collect(&:name)
    end


    # Bind services to application.
    def bind(*instances)
      self.services += instances
      update!
    end

    # Unbind services from application.
    def unbind(*instances)
      self.services -= instances
      update!
    end

    def binds?(instance)
      services.include? instance
    end

    # Retrieve file listing under path for the first instance of the application.
    #
    # [path]
    #   A sequence of strings representing path segments.
    #
    #   For example, <code>files("foo", "bar")</code> for +foo/bar+.
    def files(*path)
      Instance.new(self, "0", @client).files(*path)
    end

    # Retrieve file contents for the first instance of the application.
    #
    # [path]
    #   A sequence of strings representing path segments.
    #
    #   For example, <code>files("foo", "bar")</code> for +foo/bar+.
    def file(*path)
      Instance.new(self, "0", @client).file(*path)
    end

    private

    def set_named(attr, val)
      res = send(:"#{attr}_name=", val.name)

      if @changes.key?(attr)
        old, new = @changes[attr]
        @changes[attr] = [@client.send(attr, old), val]
      end

      res
    end

    def set_many_named(attr, vals)
      res = send(:"#{attr}_names=", val.collect(&:name))

      if @changes.key?(attr)
        old, new = @changes[attr]
        @changes[attr] = [old.collect { |o| @client.send(attr, o) }, vals]
      end

      vals
    end

    # Class represnting a running instance of an application.
    class Instance
      # The application this instance belongs to.
      attr_reader :app

      # Application instance number.
      attr_reader :id

      # Create an Instance object.
      #
      # You'll usually call App#instances instead
      def initialize(app, id, client, manifest = {})
        @app = app
        @id = id
        @client = client
        @manifest = manifest
      end

      # Show string representing the application instance.
      def inspect
        "#<App::Instance '#{@app.name}' \##@id>"
      end

      # Instance state.
      def state
        @manifest[:state]
      end
      alias_method :status, :state

      # Instance start time.
      def since
        Time.at(@manifest[:since])
      end

      # Instance debugger data. If instance is in debug mode, returns a hash
      # containing :ip and :port keys.
      def debugger
        return unless @manifest[:debug_ip] and @manifest[:debug_port]

        { :ip => @manifest[:debug_ip],
          :port => @manifest[:debug_port]
        }
      end

      # Instance console data. If instance has a console, returns a hash
      # containing :ip and :port keys.
      def console
        return unless @manifest[:console_ip] and @manifest[:console_port]

        { :ip => @manifest[:console_ip],
          :port => @manifest[:console_port]
        }
      end

      # True if instance is starting or running, false if it's down or
      # flapping.
      def healthy?
        case state
        when "STARTING", "RUNNING"
          true
        when "DOWN", "FLAPPING"
          false
        end
      end

      def files(*path)
        @client.base.files(@app.name, @id, *path).split("\n").collect do |entry|
          path + [entry.split(/\s+/, 2)[0]]
        end
      end

      def file(*path)
        @client.base.files(@app.name, @id, *path)
      end
    end
  end
end
