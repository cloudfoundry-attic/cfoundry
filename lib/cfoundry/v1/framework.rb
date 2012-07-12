module CFoundry::V1
  class Framework
    attr_accessor :name, :description

    def initialize(name, description = nil)
      @name = name
      @description = description
    end

    def apps
      [] # not supported by v1
    end
  end
end
