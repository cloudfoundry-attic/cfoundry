module CFoundry::V1
  class Service
    attr_accessor :label, :description, :version

    def initialize(label, description = nil, version = nil)
      @label = label
      @description = description
      @version = version
    end

    def provider
      "core"
    end

    def active
      true
    end
  end
end
