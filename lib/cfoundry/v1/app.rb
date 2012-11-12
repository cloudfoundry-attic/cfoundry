require "tmpdir"

require "cfoundry/zip"
require "cfoundry/upload_helpers"
require "cfoundry/chatty_hash"

require "cfoundry/v1/framework"
require "cfoundry/v1/runtime"

module CFoundry::V1
  # Class for representing a user's application on a given target (via
  # Client).
  #
  # Does not guarantee that the app exists; used for both app creation and
  # retrieval, as the attributes are all lazily retrieved. Setting attributes
  # does not perform any requests; use #update! to commit your changes.
  class App
    include CFoundry::UploadHelpers

    # Application name.
    attr_accessor :name

    # Application instance count.
    attr_accessor :total_instances

    # Services bound to the application.
    attr_accessor :services

    # Application environment variables.
    attr_accessor :env

    # Application memory limit.
    attr_accessor :memory

    # Application framework.
    attr_accessor :framework

    # Application runtime.
    attr_accessor :runtime

    # Application startup command.
    #
    # Used for standalone apps.
    attr_accessor :command

    # Application debug mode.
    attr_accessor :debug_mode

    # Application state.
    attr_accessor :state
    alias_method :status, :state

    # URIs mapped to the application.
    attr_accessor :uris
    alias_method :urls, :uris


    # Create an App object.
    #
    # You'll usually call Client#app instead
    def initialize(name, client, manifest = nil)
      @name = name
      @client = client
      @manifest = manifest
      @diff = {}
    end

    # Show string representing the application.
    def inspect
      "#<App '#@name'>"
    end

    # Basic equality test by name.
    def eql?(other)
      other.is_a?(self.class) && other.name == @name
    end
    alias :== :eql?

    # Delete the application from the target.
    #
    # Keeps the metadata, but clears target-specific state from it.
    def delete!
      @client.base.delete_app(@name)

      if @manifest
        @diff = read_manifest
        @manifest = nil
      end
    end

    # Create the application on the target.
    #
    # Call this after setting the various attributes.
    def create!
      @client.base.create_app(create_manifest)
      @diff = {}
    end

    # Check if the application exists on the target.
    def exists?
      @client.base.app(@name)
      true
    rescue CFoundry::AppNotFound
      false
    end

    # Retrieve all of the instances of the app, as Instance objects.
    def instances
      @client.base.instances(@name).collect do |m|
        Instance.new(self, m[:index].to_s, @client, m)
      end
    end

    # Retrieve crashed instances
    def crashes
      @client.base.crashes(@name).collect do |i|
        Instance.new(self, i[:instance].to_s, @client, i)
      end
    end

    # Retrieve application statistics, e.g. CPU load and memory usage.
    def stats
      stats = {}

      @client.base.stats(@name).each do |idx, info|
        stats[idx.to_s] = info
      end

      stats
    end

    # Update application attributes. Does not restart the application.
    def update!(what = {})
      what.each do |k, v|
        send(:"#{k}=", v)
      end

      @client.base.update_app(@name, update_manifest)

      @manifest = nil
      @diff = {}

      self
    end

    # Stop the application.
    def stop!
      update! :state => "STOPPED"
    end

    # Start the application.
    def start!
      update! :state => "STARTED"
    end

    # Restart the application.
    def restart!
      stop!
      start!
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
      @manifest = nil
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


    { :total_instances => :instances,
      :running_instances => :running_instances,
      :runtime_name => :runtime,
      :framework_name => :framework,
      :service_names => :services,
      :env_array => :env,
      :state => :state,
      :status => :state,
      :uris => :uris,
      :urls => :uris,
      :command => :command,
      :console => :console,
      :memory => :memory,
      :disk => :disk,
      :fds => :fds,
      :debug_mode => :debug,
      :version => :version,
      :meta_version => :meta_version,
      :created => :created
    }.each do |meth, attr|
      define_method(meth) do
        if @diff.key?(attr)
          @diff[attr]
        else
          read_manifest[attr]
        end
      end

      define_method(:"#{meth}=") do |v|
        @diff[attr] = v
      end
    end


    # Shortcut for uris[0]
    def uri
      uris[0]
    end

    # Shortcut for uris = [x]
    def uri=(x)
      self.uris = [x]
    end

    alias :url :uri
    alias :url= :uri=

    # Application framework.
    def framework
      Framework.new(framework_name)
    end

    def framework=(v) # :nodoc:
      v = v.name if v.is_a?(Framework)
      self.framework_name = v
    end

    # Application runtime.
    def runtime
      Runtime.new(runtime_name)
    end

    def runtime=(v) # :nodoc:
      v = v.name if v.is_a?(Runtime)
      self.runtime_name = v
    end

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
      update!(:services => services + instances)
    end

    # Unbind services from application.
    def unbind(*instances)
      update!(:services =>
                services.reject { |s|
                  instances.any? { |i| i.name == s.name }
                })
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

    # Upload application's code to target. Do this after #create! and before
    # #start!
    #
    # [path]
    #   A path pointing to either a directory, or a .jar, .war, or .zip
    #   file.
    #
    #   If a .vmcignore file is detected under the given path, it will be used
    #   to exclude paths from the payload, similar to a .gitignore.
    #
    # [check_resources]
    #   If set to `false`, the entire payload will be uploaded
    #   without checking the resource cache.
    #
    #   Only do this if you know what you're doing.
    def upload(path, check_resources = true)
      unless File.exist? path
        raise CFoundry::Error, "Invalid application path '#{path}'"
      end

      zipfile = "#{Dir.tmpdir}/#{@name}.zip"
      tmpdir = "#{Dir.tmpdir}/.vmc_#{@name}_files"

      FileUtils.rm_f(zipfile)
      FileUtils.rm_rf(tmpdir)

      prepare_package(path, tmpdir)

      resources = determine_resources(tmpdir) if check_resources

      packed = CFoundry::Zip.pack(tmpdir, zipfile)

      @client.base.upload_app(@name, packed && zipfile, resources || [])
    ensure
      FileUtils.rm_f(zipfile) if zipfile
      FileUtils.rm_rf(tmpdir) if tmpdir
    end

    private

    ATTR_MAP = {
      :instances => :instances,
      :state => :state,
      :env => :env,
      :uris => :uris,
      :services => :services,
      :debug => :debug,
      :console => :console,

      :framework => [:staging, :model],
      :runtime => [:staging, :stack],
      :command => [:staging, :command],

      :meta_version => [:meta, :version],
      :created => [:meta, :created],

      :memory => [:resources, :memory],
      :disk => [:resources, :disk],
      :fds => [:resources, :fds]
    }

    def manifest
      @manifest ||= @client.base.app(@name)
    end

    def write_manifest(body = read_manifest, onto = {})
      onto[:name] = @name

      ATTR_MAP.each do |what, where|
        if body.key?(what)
          put(body[what], onto, Array(where))
        end
      end

      onto
    end

    def put(what, where, path)
      if path.size == 1
        where[path.last] = what
      elsif name = path.first
        where[name] ||= {}
        put(what, where[name], path[1..-1])
      end

      nil
    end

    def update_manifest
      write_manifest(@diff, write_manifest)
    end

    def create_manifest
      write_manifest(@diff)
    end

    def read_manifest
      { :name => @name,
        :instances => manifest[:instances],
        :running_instances => manifest[:runningInstances],
        :state => manifest[:state],
        :env => manifest[:env],
        :uris => manifest[:uris],
        :version => manifest[:version],
        :services => manifest[:services],
        :framework => manifest[:staging][:model],
        :runtime => manifest[:staging][:stack],
        :console => manifest[:meta][:console],
        :meta_version => manifest[:meta][:version],
        :debug => manifest[:meta][:debug],
        :created => manifest[:meta][:created],
        :memory => manifest[:resources][:memory],
        :disk => manifest[:resources][:disk],
        :fds => manifest[:resources][:fds]
      }
    end

    # Minimum size for an application payload to bother checking resources.
    RESOURCE_CHECK_LIMIT = 64 * 1024

    def determine_resources(path)
      fingerprints, total_size = make_fingerprints(path)

      return if total_size <= RESOURCE_CHECK_LIMIT

      resources = @client.base.check_resources(fingerprints)

      resources.each do |resource|
        FileUtils.rm_f resource[:fn]
        resource[:fn].sub!("#{path}/", "")
      end

      resources
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

      # Retrieve file listing under path for this instance.
      #
      # [path]
      #   A sequence of strings representing path segments.
      #
      #   For example, <code>files("foo", "bar")</code> for +foo/bar+.
      def files(*path)
        @client.base.files(@app.name, @id, *path).split("\n").collect do |entry|
          path + [entry.split(/\s+/, 2)[0]]
        end
      end

      # Retrieve file contents for this instance.
      #
      # [path]
      #   A sequence of strings representing path segments.
      #
      #   For example, <code>files("foo", "bar")</code> for +foo/bar+.
      def file(*path)
        @client.base.files(@app.name, @id, *path)
      end
    end
  end
end
