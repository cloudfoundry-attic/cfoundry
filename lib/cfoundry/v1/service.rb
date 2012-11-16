module CFoundry::V1
  class Service
    attr_accessor :label, :version, :description, :type, :provider, :state

    def initialize(label, version = nil, description = nil,
                   type = nil, provider = "core", state = nil)
      @label = label
      @description = description
      @version = version
      @type = type
      @provider = provider
      @state = state
    end

    def eql?(other)
      other.is_a?(self.class) && other.label == @label
    end
    alias :== :eql?

    def active
      true
    end

    def deprecated?
      @state == :deprecated
    end

    def current?
      @state == :current
    end
  end
end
