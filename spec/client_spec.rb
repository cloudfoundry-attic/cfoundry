require "cfoundry"
require "./helpers"

RSpec.configure do |c|
  c.include CFoundryHelpers
end

describe CFoundry::Client do
  TARGET = ENV["CFOUNDRY_TEST_TARGET"] || "http://api.vcap.me"
  USER = ENV["CFOUNDRY_TEST_USER"] || "dev@cloudfoundry.org"
  PASSWORD = ENV["CFOUNDRY_TEST_PASSWORD"] || "test"

  before(:all) do
    @client = CFoundry::Client.new(TARGET)
    @client.login(USER, PASSWORD)
  end

  describe :target do
    it "returns the current API target" do
      @client.target.should == TARGET
    end
  end

  describe "metadata" do
    describe :info do
      it "returns the cloud meta-info" do
        @client.info.should be_a(Hash)
      end
    end

    describe :system_services do
      it "returns the service vendors" do
        @client.system_services.should be_a(Hash)
      end

      it "denies if not authenticated" do
        without_auth do
          proc {
            @client.system_services
          }.should raise_error(CFoundry::Denied)
        end
      end
    end

    describe :system_runtimes do
      it "returns the supported runtime information" do
        @client.system_runtimes.should be_a(Hash)
      end

      it "works if not authenticated" do
        without_auth do
          proc {
            @client.system_runtimes
          }.should_not raise_error(CFoundry::Denied)
        end
      end
    end
  end

  describe :user do
    it "creates a lazy User object" do
      with_new_user do
        @client.user(@user.email).should be_a(CFoundry::User)
      end
    end
  end

  describe :register do
    it "registers an account and returns the User" do
      email = random_user

      user = @client.register(email, "test")

      begin
        @client.user(email).should satisfy(&:exists?)
      ensure
        user.delete!
      end
    end

    it "fails if a user by that name already exists" do
      proc {
        @client.register(USER, PASSWORD)
      }.should raise_error(CFoundry::Denied)
    end
  end

  describe :login do
    it "authenticates and sets the client token" do
      client = CFoundry::Client.new(TARGET)
      email = random_user
      pass = random_str

      client.register(email, pass)
      begin
        client.login(email, pass)
        client.should satisfy(&:logged_in?)
      ensure
        @client.user(email).delete!
      end
    end

    it "fails with invalid credentials" do
      client = CFoundry::Client.new(TARGET)
      email = random_user

      client.register(email, "right")
      begin
        proc {
          client.login(email, "wrong")
        }.should raise_error(CFoundry::Denied)
      ensure
        @client.user(email).delete!
      end
    end
  end

  describe :logout do
    it "clears the login token" do
      client = CFoundry::Client.new(TARGET)
      email = random_user
      pass = random_str

      client.register(email, pass)

      begin
        client.login(email, pass)
        client.should satisfy(&:logged_in?)

        client.logout
        client.should_not satisfy(&:logged_in?)
      ensure
        @client.user(email).delete!
      end
    end
  end

  describe :app do
    it "creates a lazy App object" do
      @client.app("foo").should be_a(CFoundry::App)
      @client.app("foo").name.should == "foo"
    end
  end

  describe :apps do
    it "returns an empty array if a user has no apps" do
      with_new_user do
        @client.apps.should == []
      end
    end

    it "returns an array of App objects if a user has any" do
      with_new_user do
        name = random_str

        new = @client.app(name)
        new.total_instances = 1
        new.urls = []
        new.framework = "sinatra"
        new.runtime = "ruby18"
        new.memory = 64
        new.create!

        apps = @client.apps
        apps.should be_a(Array)
        apps.size.should == 1
        apps.first.should be_a(CFoundry::App)
        apps.first.name.should == name
      end
    end
  end

  describe :service do
    it "creates a lazy Service object" do
      @client.service("foo").should be_a(CFoundry::Service)
      @client.service("foo").name.should == "foo"
    end
  end

  describe :services do
    it "returns an empty array if a user has no apps" do
      with_new_user do
        @client.services.should == []
      end
    end

    it "returns an array of Service objects if a user has any" do
      with_new_user do
        name = random_str

        new = @client.service(name)
        new.type = "key-value"
        new.vendor = "redis"
        new.version = "2.2"
        new.tier = "free"
        new.create!

        svcs = @client.services
        svcs.should be_a(Array)
        svcs.size.should == 1
        svcs.first.should be_a(CFoundry::Service)
        svcs.first.name.should == name
      end
    end
  end
end
