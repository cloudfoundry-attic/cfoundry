require "fileutils"
require "digest/sha1"
require "pathname"
require "tmpdir"

require "cfoundry/zip"

module CFoundry
  class App
    attr_reader :name

    def initialize(name, client, manifest = nil)
      @name = name
      @client = client
      @manifest = manifest
    end

    def inspect
      "#<App '#@name'>"
    end

    def manifest
      @manifest ||= @client.rest.app(@name)
    end

    def delete!
      @client.rest.delete_app(@name)

      if @manifest
        @manifest.delete "meta"
        @manifest.delete "version"
        @manifest.delete "state"
      end
    end

    def create!
      @client.rest.create_app(@manifest.merge("name" => @name))
      @manifest = nil
    end

    def exists?
      @client.rest.app(@name)
      true
    rescue CFoundry::NotFound
      false
    end

    def instances
      @client.rest.instances(@name).collect do |m|
        Instance.new(@name, m["index"], @client, m)
      end
    end

    def stats
      @client.rest.stats(@name)
    end

    def update!(what = {})
      # TODO: hacky; can we not just set in meta field?
      # we write to manifest["debug"] but read from manifest["meta"]["debug"]
      what[:debug] = debug_mode

      @client.rest.update_app(@name, manifest.merge(what))
      @manifest = nil
    end

    def stop!
      update! "state" => "STOPPED"
    end

    def start!
      update! "state" => "STARTED"
    end

    def restart!
      stop!
      start!
    end

    def health
      s = state
      if s == "STARTED"
        healthy_count = manifest["runningInstances"]
        expected = manifest["instances"]
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

    def healthy?
      # invalidate cache so the check is fresh
      @manifest = nil
      health == "RUNNING"
    end

    def stopped?
      state == "STOPPED"
    end

    def started?
      state == "STARTED"
    end
    alias_method :running?, :started?

    { :total_instances => "instances",
      :state => "state",
      :status => "state",
      :services => "services",
      :uris => "uris",
      :urls => "uris",
      :env => "env"
    }.each do |meth, attr|
      define_method(meth) do
        manifest[attr]
      end

      define_method(:"#{meth}=") do |v|
        @manifest ||= {}
        @manifest[attr] = v
      end
    end

    def uri
      uris[0]
    end

    def uri=(x)
      self.uris = [x]
    end

    alias :url :uri
    alias :url= :uri=

    def framework
      manifest["staging"]["framework"] ||
        manifest["staging"]["model"]
    end

    def framework=(v)
      @manifest ||= {}
      @manifest["staging"] ||= {}

      if @manifest["staging"].key? "model"
        @manifest["staging"]["model"] = v
      else
        @manifest["staging"]["framework"] = v
      end
    end

    def runtime
      manifest["staging"]["runtime"] ||
        manifest["staging"]["stack"]
    end

    def runtime=(v)
      @manifest ||= {}
      @manifest["staging"] ||= {}

      if @manifest["staging"].key? "stack"
        @manifest["staging"]["stack"] = v
      else
        @manifest["staging"]["runtime"] = v
      end
    end

    def command
      manifest["staging"]["command"]
    end

    def command=(v)
      @manifest ||= {}
      @manifest["staging"] ||= {}
      @manifest["staging"]["command"] = v
    end

    def memory
      manifest["resources"]["memory"]
    end

    def memory=(v)
      @manifest ||= {}
      @manifest["resources"] ||= {}
      @manifest["resources"]["memory"] = v
    end

    def debug_mode
      manifest.fetch("debug") { manifest["meta"] && manifest["meta"]["debug"] }
    end

    def debug_mode=(v)
      @manifest ||= {}
      @manifest["debug"] = v
    end

    def bind(*service_names)
      update!("services" => services + service_names)
    end

    def unbind(*service_names)
      update!("services" =>
                services.reject { |s|
                  service_names.include?(s)
                })
    end

    def files(*path)
      Instance.new(@name, 0, @client).files(*path)
    end

    def file(*path)
      Instance.new(@name, 0, @client).file(*path)
    end

    UPLOAD_EXCLUDE = %w{.git _darcs .svn}

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

    def prepare_package(path, to)
      if path =~ /\.(war|zip)$/
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
        FileUtils.rm_f resource["fn"]
        resource["fn"].sub!("#{path}/", '')
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

    class Instance
      attr_reader :app, :index, :manifest

      def initialize(appname, index, client, manifest = {})
        @app = appname
        @index = index
        @client = client
        @manifest = manifest
      end

      def inspect
        "#<App::Instance '#@app' \##@index>"
      end

      def state
        @manifest["state"]
      end
      alias_method :status, :state

      def since
        Time.at(@manifest["since"])
      end

      def debugger
        return unless @manifest["debug_ip"] and @manifest["debug_port"]
        { "ip" => @manifest["debug_ip"],
          "port" => @manifest["debug_port"]
        }
      end

      def console
        return unless @manifest["console_ip"] and @manifest["console_port"]
        { "ip" => @manifest["console_ip"],
          "port" => @manifest["console_port"]
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
        @client.rest.files(@app, @index, *path).split("\n").collect do |entry|
          path + [entry.split(/\s+/, 2)[0]]
        end
      end

      def file(*path)
        @client.rest.files(@app, @index, *path)
      end
    end
  end
end
