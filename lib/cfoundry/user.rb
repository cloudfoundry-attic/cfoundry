module CFoundry
  class User
    attr_reader :email

    def initialize(email, client, manifest = nil)
      @email = email
      @client = client
      @manifest = manifest
    end

    def inspect
      "#<User '#@email'>"
    end

    def manifest
      @manifest ||= @client.rest.user(@email)
    end

    def delete!
      @client.rest.delete_user(@email)
    end

    def create!
      @client.rest.create_user(@manifest.merge("email" => @email))
    end

    def update!(what = {})
      @client.rest.update_user(@email, manifest.merge(what))
      @manifest = nil
    end

    def exists?
      @client.rest.user(@email)
      true
    rescue CFoundry::Denied
      false
    end

    def admin?
      manifest["admin"]
    end

    def password=(str)
      manifest["password"] = str
    end
  end
end
