module CFoundry::V1
  class Service
    attr_accessor :label, :version, :description, :type, :provider

    def initialize(label, version = nil, description = nil,
                   type = nil, provider = "core")
      @label = label
      @description = description
      @version = version
      @type = type
      @provider = provider
    end

    def eql?(other)
      other.is_a?(self.class) && other.label == @label
    end
    alias :== :eql?

    def active
      true
    end
  end
end
