require 'json'

module CcApiStub
  module Helper
    class << self
      def response(code, body=nil)
        {
          :status => code,
          :headers => {},
          :body => body.nil? ? "--garbage--" : body.to_json
        }
      end

      def fail_request(method = :any, code = 500, response_body = {}, path = /#{CcApiStub::Helper.host}/)
        WebMock::API.stub_request(method, path).to_return(response(code, response_body))
      end

      def host=(host)
        @@host = host
      end

      def host
        @@host or raise 'No host set'
      end

      def fail_with_error(method, error_attributes=nil)
        WebMock::API.
          stub_request(method, /#{CcApiStub::Helper.host}/).
          to_return(response(400, error_attributes))
      end

      def load_fixtures(fixture_name_or_path, options = {})
        path = if options.delete(:use_local_fixture)
          fixture_name_or_path
        else
          File.join(File.dirname(__FILE__), "..", "..", "spec/fixtures/#{fixture_name_or_path.to_s}.json")
        end
        JSON.parse(File.read(path)).tap do |fixture|
          fixture["entity"].merge!(options.stringify_keys) if options.any?
        end
      end
    end

    def stub_get(*args)
      stub_request(:get, *args)
    end

    def stub_post(*args)
      stub_request(:post, *args)
    end

    def stub_put(*args)
      stub_request(:put, *args)
    end

    def stub_delete(*args)
      stub_request(:delete, *args)
    end

    def stub_request(method, path, params = nil, response = nil)
      stub = WebMock::API.stub_request(method, path)
      stub.to_return(response) if response
      stub.with(params) if params
      stub
    end

    def object_name
      name.demodulize.underscore.singularize
    end

    def find_fixture(fixture_name)
      begin
        Helper.load_fixtures("fake_#{fixture_name}")
      rescue
        Helper.load_fixtures("fake_organization_#{fixture_name}")
      end
    end

    def object_class
      begin
        object_name.camelcase.constantize
      rescue
        "Organization::#{object_name.camelcase}".constantize
      rescue
        "User::#{object_name.camelcase}".constantize
      end
    end

    def response(code, body=nil)
      CcApiStub::Helper.response(code, body)
    end

    def succeed_to_load(options={})
      response_body = response_from_options(options.reverse_merge!({:fixture => "fake_cc_#{object_name}"}))
      stub_get(object_endpoint(options[:id]), {}, response(200, response_body))
    end

    def fail_to_load(options = {})
      stub_get(object_endpoint(options[:id]), {}, response(500))
    end

    def succeed_to_load_many(options={})
      response_body = response_from_options(options.reverse_merge!({:fixture => "fake_cc_#{object_name.pluralize}"}))
      stub_get(collection_endpoint, {}, response(200, response_body))
    end

    def succeed_to_load_empty(options = {})
      root = options[:root] || object_name.pluralize
      stub_get(collection_endpoint, {}, response(200, {root => [], "pagination" => {}}))
    end

    def fail_to_load_many
      stub_get(collection_endpoint, {}, response(500))
    end

    def succeed_to_create
      response_body = {object_name.to_sym => {:id => "#{object_name.gsub("_", "-")}-id-1"}}
      stub_post(collection_endpoint, {}, response(201, response_body))
    end

    def succeed_to_update(options = {})
      stub_put(object_endpoint(options[:id]), nil, response(200, response_from_options(options)))
    end

    def fail_to_update(options = {})
      stub_put(object_endpoint(options[:id]), nil, response(500, {}))
    end

    def succeed_to_delete(options = {})
      stub_delete(object_endpoint(options[:id]), nil, response(200))
    end

    alias_method :succeed_to_leave, :succeed_to_delete

    def fixture_prefix
      "_cc"
    end

    private

    def response_from_options(options)
      fixture = options.delete(:fixture)
      return options[:response] if options[:response]
      return CcApiStub::Helper.load_fixtures(fixture, options) if fixture
      {}
    end
  end
end
