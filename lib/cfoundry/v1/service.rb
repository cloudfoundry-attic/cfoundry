module CFoundry::V1
  class Service
    attr_accessor :label, :version, :description, :type

    def initialize(label, version = nil, description = nil, type = nil)
      @label = label
      @description = description
      @version = version
      @type = nil
    end

    def eql?(other)
      other.is_a?(self.class) && other.label == @label
    end
    alias :== :eql?

    def provider
      "core"
    end

    def active
      true
    end
  end
end
