require "cfoundry/baseclient"
require "uaa"

module CFoundry
  class UAAClient
    attr_accessor :target, :client_id, :token, :trace, :http_proxy, :https_proxy

    def initialize(target, client_id = "cf", options = {})
      @target = target
      @client_id = client_id
      @http_proxy = options[:http_proxy]
      @https_proxy = options[:https_proxy]
      @uaa_info_client = uaa_info_client_for(target)
    end

    def prompts
      wrap_uaa_errors do
        @uaa_info_client.server[:prompts]
      end
    end

    def authorize(credentials)
      wrap_uaa_errors do
        authenticate_with_password_grant(credentials) ||
          authenticate_with_implicit_grant(credentials)
      end
    end

    def user(guid)
      wrap_uaa_errors do
        scim.get(:user, guid)
      end
    end

    def users
      wrap_uaa_errors do
        scim.query(:user)
      end
    end

    def change_password(guid, new, old)
      wrap_uaa_errors do
        scim.change_password(guid, new, old)
      end
    end

    def password_score(password)
      wrap_uaa_errors do
        response = uaa_info_client_for(uaa_url).password_strength(password)

        required_score = response[:requiredScore] || 0
        case (response[:score] || 0)
          when 10 then
            :strong
          when required_score..9 then
            :good
          else
            :weak
        end
      end
    end

    def add_user(email, password, options = {})
      wrap_uaa_errors do
        scim.add(
          :user,
          {:userName => email,
            :emails => [{:value => email}],
            :password => password,
            :name => {:givenName => options[:givenName] || email,
                      :familyName => options[:familyName] || email}
          }
        )
      end
    end

    def delete_user(guid)
      wrap_uaa_errors do
        scim.delete(:user, guid)
      end
    end

    def try_to_refresh_token!
      wrap_uaa_errors do
        begin
          token_info = token_issuer.refresh_token_grant(token.refresh_token)
          self.token = AuthToken.from_uaa_token_info(token_info)
        rescue CF::UAA::TargetError
          self.token
        end
      end
    end

    private

    def uaa_info_client_for(url)
      CF::UAA::Info.new(url,
                        :symbolize_keys => true,
                        :http_proxy => http_proxy,
                        :https_proxy => https_proxy
      )
    end

    def token_issuer
      @token_issuer ||= CF::UAA::TokenIssuer.new(target, client_id, nil,
        :symbolize_keys => true,
        :http_proxy => @http_proxy,
        :https_proxy => @https_proxy
      )

      if @trace
        @token_issuer.logger = CF::UAA::Util.default_logger(:trace, STDERR)
        CF::UAA::Util.default_logger(nil, STDOUT)
      else
        @token_issuer.logger.level = Logger::INFO
      end

      @token_issuer
    end

    def scim
      auth_header = token && token.auth_header
      scim = CF::UAA::Scim.new(uaa_url, auth_header, :symbolize_keys => true)
      scim.logger.level = @trace ? Logger::Severity::TRACE : 1
      scim
    end

    def uaa_url
      @uaa_url ||= @uaa_info_client.discover_uaa
    end

    def authenticate_with_password_grant(credentials)
      begin
        # Currently owner_password_grant method does not allow
        # non-password based authenticate; so we have cheat a little bit.
        token_issuer.send(:request_token,
          {:grant_type => "password", :scope => nil}.merge(credentials))
      rescue CF::UAA::BadResponse => e
        status_code = e.message[/\d+/] || 400
        raise CFoundry::Denied.new("Authorization failed", status_code)
      rescue CF::UAA::TargetError
        false
      end
    end

    def authenticate_with_implicit_grant(credentials)
      begin
        token_issuer.implicit_grant_with_creds(credentials)
      rescue CF::UAA::BadResponse => e
        status_code = e.message[/\d+/] || 400
        raise CFoundry::Denied.new("Authorization failed", status_code)
      end
    end

    def wrap_uaa_errors
      yield
    rescue CF::UAA::BadResponse
      raise CFoundry::BadResponse
    rescue CF::UAA::NotFound
      raise CFoundry::NotFound
    rescue CF::UAA::InvalidToken
      raise CFoundry::Denied
    rescue CF::UAA::TargetError => e
      raise CFoundry::UAAError.new(e.info[:error_description], e.info[:error])
    end
  end
end
