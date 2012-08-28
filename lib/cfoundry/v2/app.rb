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
    attribute :production,       :boolean, :default => false
    to_one    :space
    to_one    :runtime
    to_one    :framework
    attribute :environment_json, :hash,    :default => {}
    attribute :memory,           :integer, :default => 256
    attribute :instances,        :integer, :default => 1
    attribute :file_descriptors, :integer, :default => 256
    attribute :disk_quota,       :integer, :default => 256
    attribute :state,            :integer, :default => "STOPPED"
    to_many   :service_bindings

    alias :total_instances :instances
    alias :total_instances= :instances=

    private :environment_json, :environment_json=

    def services
      service_bindings.collect(&:service_instance)
    end

    def env
      @env ||= CFoundry::ChattyHash.new(
        method(:env=),
        MultiJson.load(environment_json))
    end

    def env=(hash)
      @env = hash
      @diff["environment_json"] = hash
      hash
    end

    def command # TODO v2
      nil
    end

    def debug_mode # TODO v2
      nil
    end

    def console # TODO v2
      nil
    end

    def uris # TODO v2
      []
    end
    alias :urls :uris

    def uris=(x)
      nil
    end
    alias :urls= :uris=

    def uri
      uris[0]
    end
    alias :url :uri

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
      state
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

      zipfile = "#{Dir.tmpdir}/#{@guid}.zip"
      tmpdir = "#{Dir.tmpdir}/.vmc_#{@guid}_files"

      FileUtils.rm_f(zipfile)
      FileUtils.rm_rf(tmpdir)

      prepare_package(path, tmpdir)

      resources = determine_resources(tmpdir) if check_resources

      packed = CFoundry::Zip.pack(tmpdir, zipfile)

      @client.base.upload_app(@guid, packed && zipfile, resources || [])
    ensure
      FileUtils.rm_f(zipfile) if zipfile
      FileUtils.rm_rf(tmpdir) if tmpdir
    end

    private

    # Minimum size for an application payload to bother checking resources.
    RESOURCE_CHECK_LIMIT = 64 * 1024

    def determine_resources(path)
      fingerprints, total_size = make_fingerprints(path)

      return if total_size <= RESOURCE_CHECK_LIMIT

      resources = @client.base.resource_match(fingerprints)

      resources.each do |resource|
        FileUtils.rm_f resource[:fn]
        resource[:fn].sub!("#{path}/", "")
      end

      resources
    end
  end
end
