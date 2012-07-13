module CFoundry::V1
  class Service
    attr_accessor :label, :version, :description, :type

    def initialize(label, version = nil, description = nil, type = nil)
      @label = label
      @description = description
      @version = version
      @type = nil
    end

    def provider
      "core"
    end

    def active
      true
    end
  end
end
