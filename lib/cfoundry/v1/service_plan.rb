module CFoundry::V1

  class ServicePlan

    attr_accessor :name, :description

    def initialize(name, description, is_default)
      @name = name
      @description = description
      @is_default = is_default
    end

    def default?
      @is_default
    end

  end

end
