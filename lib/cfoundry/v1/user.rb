require "cfoundry/v1/model"

module CFoundry::V1
  class User < Model
    attribute :email,    :string, :guid => true
    attribute :password, :string, :write_only => true
    attribute :admin,    :boolean

    define_client_methods

    alias_method :admin?, :admin

    def change_password!(new, old)
      if @client.base.uaa
        @client.base.uaa.change_password(guid, new, old)
      else
        self.password = new
        update!
      end
    end
  end
end
