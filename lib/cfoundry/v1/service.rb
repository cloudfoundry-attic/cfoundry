module CFoundry::V1
  class Service
    attr_accessor :label, :version, :description, :type, :provider, :state, :service_plans

    def initialize(label, version = nil, description = nil,
                   type = nil, provider = "core", state = nil,
                   service_plans = [])
      @label = label
      @description = description
      @version = version
      @type = type
      @provider = provider
      @state = state
      @service_plans = service_plans
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

    def default_service_plan
      service_plans.find(&:default?)
    end

  end
end
