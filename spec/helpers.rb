module CFoundryHelpers
  def random_str
    format("%x", rand(1000000))
  end

  def random_user
    "#{random_str}@cfoundry-spec.com"
  end

  def without_auth
    proxy = @client.proxy
    @client.logout
    @client.proxy = nil
    yield
  ensure
    @client.login(USER, PASSWORD)
    @client.proxy = proxy
  end

  def with_new_user
    @user = @client.register(random_user, "test")
    @client.proxy = @user.email
    yield
  ensure
    @client.proxy = nil
    @user.delete!
    @user = nil
  end
end
