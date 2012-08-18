module CFoundry::V1
  class Framework
    attr_accessor :name, :description, :runtimes, :detection

    def initialize(name, description = nil, runtimes = [], detection = nil)
      @name = name
      @description = description
      @runtimes = runtimes
      @detection = detection
    end

    def eql?(other)
      other.is_a?(self.class) && other.name == @name
    end
    alias :== :eql?

    def apps
      [] # not supported by v1
    end
  end
end
