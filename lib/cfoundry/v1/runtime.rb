module CFoundry::V1
  class Runtime
    attr_accessor :name, :description, :debug_modes,
      :version, :status, :series, :category

    def initialize(name, description = nil, debug_modes = nil,
                   version = nil, status = nil, series = nil,
                   category = nil)
      @name = name
      @description = description
      @debug_modes = debug_modes
      @version = version
      @status = status
      @series = series
      @category = category
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
