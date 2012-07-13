module CFoundry::V1
  class Framework
    attr_accessor :name, :description, :runtimes, :detection

    def initialize(name, description = nil, runtimes = [], detection = nil)
      @name = name
      @description = description
      @runtimes = runtimes
      @detection = detection
    end

    def apps
      [] # not supported by v1
    end
  end
end
