module CFoundry::V1
  class Runtime
    attr_accessor :name, :description, :debug_modes

    def initialize(name, description = nil, debug_modes = nil)
      @name = name
      @description = description
      @debug_modes = debug_modes
    end

    def apps
      [] # not supported by v1
    end
  end
end
