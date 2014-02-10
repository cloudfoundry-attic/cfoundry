require "cfoundry/v2/model"

module CFoundry
  module V2
    class User < Model
      to_many :spaces
      to_many :organizations
      to_many :managed_organizations, :as => :organization
      to_many :billing_managed_organizations, :as => :organization
      to_many :audited_organizations, :as => :organization
      to_many :managed_spaces, :as => :space
      to_many :audited_spaces, :as => :space
      attribute :admin, :boolean
      to_one :default_space, :as => :space

      attribute :guid, :string # guid is explicitly set for users

      queryable_by :space_guid, :organization_guid, :managed_organization_guid,
                   :billing_managed_organization_guid, :audited_organization_guid,
                   :managed_space_guid, :audited_space_guid

      def guid
        @guid
      end

      alias set_guid_attribute guid=

      def guid=(x)
        @guid = x
        set_guid_attribute(x)
      end

      alias :admin? :admin

      def change_password!(new, old)
        @client.base.uaa.change_password(@guid, new, old)
      end

      # optional metadata from UAA
      attr_accessor :emails, :name

      def email
        # if the email collection is nil or empty? collect from UAA
        get_meta_from_uaa if @emails.nil?

        return unless @emails && @emails.first
        @emails.first[:value]
      end

      def given_name
        get_meta_from_uaa if @name.nil?

        return unless @name && @name[:givenName] != email
        @name[:givenName]
      end

      def family_name
        get_meta_from_uaa if @name.nil?

        return unless @name && @name[:familyName] != email
        @name[:familyName]
      end

      def full_name
        if @name && @name[:fullName]
          @name[:fullName]
        elsif given_name && family_name
          "#{given_name} #{family_name}"
        end
      end

      def delete! (options = {})
        super(options)
        @client.base.uaa.delete_user(guid)
        true
      end

      private 

      def get_meta_from_uaa
        user = @client.base.uaa.user(guid)
        return if user.nil?
        return if not user[:error].nil?
        
        @emails = user[:emails]

        if not user[:name].nil?
          @name ||= {}
          @name[:familyName] = user[:name][:familyname]
          @name[:givenName] = user[:name][:givenname]
        end

      end

    end
  end
end
