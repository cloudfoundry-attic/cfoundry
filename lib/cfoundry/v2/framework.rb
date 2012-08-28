require "cfoundry/v2/model"

module CFoundry::V2
  class Framework < Model
    attribute :name, :string
    attribute :description, :string
    to_many   :apps

    def detection
      nil # TODO for v2?
    end

    def runtimes
      [] # TODO for v2?
    end
  end
end

