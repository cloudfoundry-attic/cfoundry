module CFoundry
  class Service
    attr_reader :name

    def initialize(name, client, manifest = nil)
      @name = name
      @client = client
      @manifest = manifest
    end

    def inspect
      "#<Service '#@name'>"
    end

    def manifest
      @manifest ||= @client.rest.service(@name)
    end

    def delete!
      @client.rest.delete_service(@name)
    end

    def create!
      @client.rest.create_service(@manifest.merge("name" => @name))
    end

    def exists?
      @client.rest.service(@name)
      true
    rescue CFoundry::NotFound
      false
    end

    def created
      Time.at(meta["created"])
    end

    def updated
      Time.at(meta["updated"])
    end

    { :type => "type",
      :vendor => "vendor",
      :version => "version",
      :properties => "properties",
      :tier => "tier",
      :meta => "meta"
    }.each do |meth, attr|
      define_method(meth) do
        manifest[attr]
      end

      define_method(:"#{meth}=") do |v|
        @manifest ||= {}
        @manifest[attr] = v
      end
    end
  end
end
