require "cfoundry/baseclient"

require "cfoundry/v1/client"
require "cfoundry/v2/client"

module CFoundry
  class Client < BaseClient
    def self.new(*args)
      target, _ = args

      base = super(target)

      case base.info[:version]
      when 2
        CFoundry::V2::Client.new(*args)
      else
        CFoundry::V1::Client.new(*args)
      end
    end

    def info
      get("info", :accept => :json)
    end
  end
end
