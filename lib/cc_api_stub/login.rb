module CcApiStub
  module Login
    class << self
      def succeeds_to_find_uaa(domain="http://some-other-random-domain.com:8181")
        WebMock::API.stub_request(:get, "#{domain}/info").
          to_return(
            :status => 200,
            :body => "{\"authorization_endpoint\":\"https://uaa.localhost\"}"
          )
      end

      def succeeds_to_login_as_admin
        WebMock::API.stub_request(:post, %r{uaa.localhost/oauth/authorize}).
          to_return(
            :status => 302,
            :headers => {"Location" => "https://uaa.localhost/redirect/vmc#access_token=sre-admin-access-token&token_type=bearer"}
          )
      end
    end
  end
end
