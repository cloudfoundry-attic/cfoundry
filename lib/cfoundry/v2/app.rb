require "fileutils"
require "digest/sha1"
require "pathname"
require "tmpdir"

require "cfoundry/zip"
require "cfoundry/v2/model"

module CFoundry::V2
  # Class for representing a user's application on a given target (via
  # Client).
  #
  # Does not guarantee that the app exists; used for both app creation and
  # retrieval, as the attributes are all lazily retrieved. Setting attributes
  # does not perform any requests; use #update! to commit your changes.
  class App < Model
    attribute :name
    attribute :production
    to_one    :app_space
    to_one    :runtime
    to_one    :framework
    attribute :environment_json,    :default => {}
    attribute :memory,              :default => 256
    attribute :instances,           :default => 1
    attribute :file_descriptors,    :default => 256
    attribute :disk_quota,          :default => 256
    attribute :state,               :default => "STOPPED"
    to_many   :service_bindings

    alias :total_instances :instances
    alias :total_instances= :instances=

    alias :services :service_bindings
    alias :services= :service_bindings=

    alias :space :app_space
    alias :space= :app_space=

    def debug_mode # TODO v2
      nil
    end
    alias :console :debug_mode

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
  end
end
