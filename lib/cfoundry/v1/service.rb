module CFoundry::V1
  # Class for representing a user's service on a given target (via Client).
  #
  # Does not guarantee that the service exists; used for both service creation
  # and retrieval, as the attributes are all lazily retrieved. Setting
  # attributes does not perform any requests; use #update! to commit your
  # changes.
  class Service
    # Service name.
    attr_reader :name

    # Service type (e.g. key-value).
    attr_accessor :type

    # Service vendor (redis, mysql, etc.).
    attr_accessor :vendor

    # Service version.
    attr_accessor :version

    # Service properties.
    attr_accessor :properties

    # Service tier. Usually "free" for now.
    attr_accessor :tier

    # Service metadata.
    attr_accessor :meta

    # Create a Service object.
    #
    # You'll usually call Client#service instead.
    def initialize(name, client, manifest = nil)
      @name = name
      @client = client
      @manifest = manifest
    end

    # Show string representing the service.
    def inspect
      "#<Service '#@name'>"
    end

    # Delete the service from the target.
    def delete!
      @client.rest.delete_service(@name)
    end

    # Create the service on the target.
    #
    # Call this after setting the various attributes.
    def create!
      @client.rest.create_service(@manifest.merge(:name => @name))
    end

    # Check if the service exists on the target.
    def exists?
      @client.rest.service(@name)
      true
    rescue CFoundry::NotFound
      false
    end

    # Timestamp of when the service was created.
    def created
      Time.at(meta[:created])
    end

    # Timestamp of when the service was last updated.
    def updated
      Time.at(meta[:updated])
    end

    { :type => :type,
      :vendor => :vendor,
      :version => :version,
      :properties => :properties,
      :tier => :tier,
      :meta => :meta
    }.each do |meth, attr|
      define_method(meth) do
        manifest[attr]
      end

      define_method(:"#{meth}=") do |v|
        @manifest ||= {}
        @manifest[attr] = v
      end
    end

    private

    def manifest
      @manifest ||= @client.rest.service(@name)
    end
  end
end
