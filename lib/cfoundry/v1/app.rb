require "fileutils"
require "digest/sha1"
require "pathname"
require "tmpdir"

require "cfoundry/zip"

module CFoundry::V1
  # Class for representing a user's application on a given target (via
  # Client).
  #
  # Does not guarantee that the app exists; used for both app creation and
  # retrieval, as the attributes are all lazily retrieved. Setting attributes
  # does not perform any requests; use #update! to commit your changes.
  class App
    # Application name.
    attr_reader :name

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
    end

    # Show string representing the application.
    def inspect
      "#<App '#@name'>"
    end

    # Delete the application from the target.
    #
    # Keeps the metadata, but clears target-specific state from it.
    def delete!
      @client.rest.delete_app(@name)

      if @manifest
        @manifest.delete :meta
        @manifest.delete :version
        @manifest.delete :state
      end
    end

    # Create the application on the target.
    #
    # Call this after setting the various attributes.
    def create!
      @client.rest.create_app(@manifest.merge(:name => @name))
      @manifest = nil
    end

    # Check if the application exists on the target.
    def exists?
      @client.rest.app(@name)
      true
    rescue CFoundry::NotFound
      false
    end

    # Retrieve all of the instances of the app, as Instance objects.
    def instances
      @client.rest.instances(@name).collect do |m|
        Instance.new(@name, m[:index], @client, m)
      end
    end

    # Retrieve application statistics, e.g. CPU load and memory usage.
    def stats
      @client.rest.stats(@name)
    end

    # Update application attributes. Does not restart the application.
    def update!(what = {})
      # TODO: hacky; can we not just set in meta field?
      # we write to manifest[:debug] but read from manifest[:meta][:debug]
      what[:debug] = debug_mode

      @client.rest.update_app(@name, manifest.merge(what))
      @manifest = nil
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
        healthy_count = manifest[:runningInstances]
        expected = manifest[:instances]
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
      :state => :state,
      :status => :state,
      :services => :services,
      :uris => :uris,
      :urls => :uris,
      :env => :env
    }.each do |meth, attr|
      define_method(meth) do
        manifest[attr]
      end

      define_method(:"#{meth}=") do |v|
        @manifest ||= {}
        @manifest[attr] = v
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
      manifest[:staging][:framework] ||
        manifest[:staging][:model]
    end

    def framework=(v) # :nodoc:
      @manifest ||= {}
      @manifest[:staging] ||= {}

      if @manifest[:staging].key? :model
        @manifest[:staging][:model] = v
      else
        @manifest[:staging][:framework] = v
      end
    end

    # Application runtime.
    def runtime
      manifest[:staging][:runtime] ||
        manifest[:staging][:stack]
    end

    def runtime=(v) # :nodoc:
      @manifest ||= {}
      @manifest[:staging] ||= {}

      if @manifest[:staging].key? :stack
        @manifest[:staging][:stack] = v
      else
        @manifest[:staging][:runtime] = v
      end
    end


    # Application startup command.
    #
    # Used for standalone apps.
    def command
      manifest[:staging][:command]
    end

    def command=(v) # :nodoc:
      @manifest ||= {}
      @manifest[:staging] ||= {}
      @manifest[:staging][:command] = v
    end


    # Application memory.
    def memory
      manifest[:resources][:memory]
    end

    def memory=(v) # :nodoc:
      @manifest ||= {}
      @manifest[:resources] ||= {}
      @manifest[:resources][:memory] = v
    end


    # Application debug mode.
    def debug_mode
      manifest.fetch(:debug) do
        manifest[:meta] && manifest[:meta][:debug]
      end
    end

    def debug_mode=(v) # :nodoc:
      @manifest ||= {}
      @manifest[:debug] = v
    end


    # Bind services to application.
    def bind(*service_names)
      update!(:services => services + service_names)
    end

    # Unbind services from application.
    def unbind(*service_names)
      update!(:services =>
                services.reject { |s|
                  service_names.include?(s)
                })
    end

    # Retrieve file listing under path for the first instance of the application.
    #
    # [path]
    #   A sequence of strings representing path segments.
    #
    #   For example, <code>files("foo", "bar")</code> for +foo/bar+.
    def files(*path)
      Instance.new(@name, 0, @client).files(*path)
    end

    # Retrieve file contents for the first instance of the application.
    #
    # [path]
    #   A sequence of strings representing path segments.
    #
    #   For example, <code>files("foo", "bar")</code> for +foo/bar+.
    def file(*path)
      Instance.new(@name, 0, @client).file(*path)
    end

    # Default paths to exclude from upload payload.
    UPLOAD_EXCLUDE = %w{.git _darcs .svn}

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
        raise "invalid application path '#{path}'"
      end

      zipfile = "#{Dir.tmpdir}/#{@name}.zip"
      tmpdir = "#{Dir.tmpdir}/.vmc_#{@name}_files"

      FileUtils.rm_f(zipfile)
      FileUtils.rm_rf(tmpdir)

      prepare_package(path, tmpdir)

      resources = determine_resources(tmpdir) if check_resources

      packed = CFoundry::Zip.pack(tmpdir, zipfile)

      @client.rest.upload_app(@name, packed && zipfile, resources || [])
    ensure
      FileUtils.rm_f(zipfile) if zipfile
      FileUtils.rm_rf(tmpdir) if tmpdir
    end

    private

    def manifest
      @manifest ||= @client.rest.app(@name)
    end

    def prepare_package(path, to)
      if path =~ /\.(jar|war|zip)$/
        CFoundry::Zip.unpack(path, to)
      elsif war_file = Dir.glob("#{path}/*.war").first
        CFoundry::Zip.unpack(war_file, to)
      else
        check_unreachable_links(path)

        FileUtils.mkdir(to)

        files = Dir.glob("#{path}/{*,.[^\.]*}")

        exclude = UPLOAD_EXCLUDE
        if File.exists?("#{path}/.vmcignore")
          exclude += File.read("#{path}/.vmcignore").split(/\n+/)
        end

        # prevent initial copying if we can, remove sub-files later
        files.reject! do |f|
          exclude.any? do |e|
            File.fnmatch(f.sub(path + "/", ""), e)
          end
        end

        FileUtils.cp_r(files, to)

        find_sockets(to).each do |s|
          File.delete s
        end

        # remove ignored globs more thoroughly
        #
        # note that the above file list only includes toplevel
        # files/directories for cp_r, so this is where sub-files/etc. are
        # removed
        exclude.each do |e|
          Dir.glob("#{to}/#{e}").each do |f|
            FileUtils.rm_rf(f)
          end
        end
      end
    end

    # Minimum size for an application payload to bother checking resources.
    RESOURCE_CHECK_LIMIT = 64 * 1024

    def determine_resources(path)
      fingerprints = []
      total_size = 0

      Dir.glob("#{path}/**/*", File::FNM_DOTMATCH) do |filename|
        next if File.directory?(filename)

        size = File.size(filename)

        total_size += size

        fingerprints << {
          :size => size,
          :sha1 => Digest::SHA1.file(filename).hexdigest,
          :fn => filename
        }
      end

      return if total_size <= RESOURCE_CHECK_LIMIT

      resources = @client.rest.check_resources(fingerprints)

      resources.each do |resource|
        FileUtils.rm_f resource[:fn]
        resource[:fn].sub!("#{path}/", "")
      end

      resources
    end

    def check_unreachable_links(path)
      files = Dir.glob("#{path}/**/*", File::FNM_DOTMATCH)

      # only used for friendlier error message
      pwd = Pathname.pwd

      abspath = File.expand_path(path)
      unreachable = []
      files.each do |f|
        file = Pathname.new(f)
        if file.symlink? && !file.realpath.to_s.start_with?(abspath)
          unreachable << file.relative_path_from(pwd)
        end
      end

      unless unreachable.empty?
        root = Pathname.new(path).relative_path_from(pwd)
        raise "Can't deploy application containing links '#{unreachable}' that reach outside its root '#{root}'"
      end
    end

    def find_sockets(path)
      files = Dir.glob("#{path}/**/*", File::FNM_DOTMATCH)
      files && files.select { |f| File.socket? f }
    end

    # Class represnting a running instance of an application.
    class Instance
      # The application this instance belongs to.
      attr_reader :app

      # Application instance number.
      attr_reader :index

      # Create an Instance object.
      #
      # You'll usually call App#instances instead
      def initialize(appname, index, client, manifest = {})
        @app = appname
        @index = index
        @client = client
        @manifest = manifest
      end

      # Show string representing the application instance.
      def inspect
        "#<App::Instance '#@app' \##@index>"
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
        @client.rest.files(@app, @index, *path).split("\n").collect do |entry|
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
        @client.rest.files(@app, @index, *path)
      end
    end
  end
end
