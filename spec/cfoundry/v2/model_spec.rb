require "spec_helper"

module CFoundry
  module V2

    # be careful, there is a TestModel in global scope because of the TestModelBuilder
    class TestModel < CFoundry::V2::Model
      attribute :foo, :string
      to_one :domain

      def create_endpoint_name
        :odd_endpoint
      end
    end

    class DefaultTestModel < CFoundry::V2::Model
      attribute :foo, :string
    end

    describe Model do
      let(:client) { build(:client) }
      let(:guid) { "my-object-guid" }
      let(:manifest) { {:metadata => {:guid => "some-guid-1"}, :entity => {}} }
      let(:model) { TestModel.new(guid, client, manifest) }

      describe "create" do
        it "uses #create!" do
          model.should_receive(:create!)
          model.create
        end

        context "without errors" do
          it "returns true" do
            model.should_receive(:create!)
            model.create.should == true
          end
        end

        context "with errors" do
          before do
            model.class.stub(:model_name) { ActiveModel::Name.new(model, nil, "abstract_model") }
            model.stub(:create!) { raise CFoundry::APIError.new("HELP") }
          end

          it "does not raise an exception" do
            expect { model.create }.to_not raise_error
          end

          it "returns false" do
            model.create.should == false
          end

          context "without model-specific errors" do
            it "adds generic base error " do
              model.create
              model.errors.full_messages.first.should =~ /cloud controller reported an error/i
            end
          end

          context "with model-specific errors" do
            it "does not set the generic error on base" do
              model.create
              model.errors.size.should == 1
            end
          end
        end
      end

      describe "#create!" do
        before do
          client.base.stub(:post) {
            {:metadata => {
                :guid => "123",
                :created_at => "2013-06-10 10:41:15 -0700",
                :updated_at => "2015-06-10 10:41:15 -0700"
            }}
          }
          model.foo = "bar"
        end

        it "posts to the model's create url with appropriate arguments" do
          client.base.should_receive(:post).with("v2", :odd_endpoint,
            :content => :json,
            :accept => :json,
            :payload => {:foo => "bar"}
          ) { {:metadata => {}} }
          model.create!
        end

        it "clears diff" do
          model.diff.should be_present
          model.create!
          model.diff.should_not be_present
        end

        it "sets manifest from the response" do
          model.create!
          model.manifest.should == {
            :metadata => {
              :guid => "123",
              :created_at => "2013-06-10 10:41:15 -0700",
              :updated_at => "2015-06-10 10:41:15 -0700"
            }
          }
        end

        it "sets guid from the response metadata" do
          model.create!
          model.guid.should == "123"
        end

        it "sets timestamps from the response metadata" do
          model.create!

          model.created_at.should == DateTime.parse("2013-06-10 10:41:15 -0700")
          model.updated_at.should == DateTime.parse("2015-06-10 10:41:15 -0700")
        end
      end

      describe "#update!" do
        before do
          client.base.stub(:put) {
            {
              :metadata => {
                :guid => guid,
                :created_at => "2013-06-10 10:41:15 -0700",
                :updated_at => "2015-06-12 10:41:15 -0700"
              },
              :entity => {
                :foo => "updated"
              }
            }
          }
        end

        it "updates using the client with the v2 api, its plural model name, object guid, and diff object" do
          model.foo = "bar"
          client.base.should_receive(:put).with("v2", :test_models, guid,
            :content => :json,
            :accept => :json,
            :payload => {:foo => "bar"}
          )
          model.update!
        end

        it "updates the updated_at timestamp" do
          model.update!
          model.updated_at.should == DateTime.parse("2015-06-12 10:41:15 -0700")
        end

        it "reloads it's data from the manifest" do
          model.update!
          model.foo.should == "updated"
        end

        it "clears diff" do
          model.foo = "bar"

          model.diff.should be_present
          model.update!
          model.diff.should_not be_present
        end
      end

      describe "delete" do
        it "uses #delete!" do
          model.should_receive(:delete!).with({}) { true }
          model.delete
        end

        it "passes options along to delete!" do
          model.should_receive(:delete!).with(:recursive => true) { true }
          model.delete(:recursive => true)
        end

        context "without errors" do
          it "returns true" do
            model.should_receive(:delete!).with({}) { true }
            model.delete.should == true
          end
        end

        context "with errors" do
          before do
            model.class.stub(:model_name) { ActiveModel::Name.new(model, nil, "abstract_model") }
            model.stub(:delete!) { raise CFoundry::APIError.new("HELP") }
          end

          it "does not raise an exception" do
            expect { model.delete }.to_not raise_error
          end

          it "returns false" do
            model.delete.should == false
          end

          context "without model-specific errors" do
            it "adds generic base error " do
              model.delete
              model.errors.full_messages.first.should =~ /cloud controller reported an error/i
            end
          end

          context "with model-specific errors" do
            it "does not set the generic error on base" do
              model.delete
              model.errors.size.should == 1
            end
          end
        end
      end

      describe "#delete!" do
        before { client.base.stub(:delete) }

        context "without options" do
          it "deletes using the client with the v2 api, its plural model name, object guid, and empty params hash" do
            client.base.should_receive(:delete).with("v2", :test_models, guid, :params => {})
            model.delete!
          end
        end

        context "with options" do
          it "sends delete with the object guid and options" do
            options = {:excellent => "billandted"}
            client.base.should_receive(:delete).with("v2", :test_models, guid, :params => options)

            model.delete!(options)
          end
        end

        it "clears its manifest metadata" do
          model.manifest.should have_key(:metadata)
          model.delete!
          model.manifest.should_not have_key(:metadata)
        end

        it "clears the diff" do
          model.foo = "bar"
          model.diff.should be_present
          model.delete!
          model.diff.should_not be_present
        end

        it "delete me" do
          begin
            model.delete!
          rescue => ex
            ex.message.should_not =~ /\?/
          end
        end
      end

      describe "#to_key" do
        context "when persisted" do
          it "returns an enumerable containing the guid" do
            model.to_key.should respond_to(:each)
            model.to_key.first.should == guid
          end
        end

        context "when not persisted" do
          let(:guid) { nil }

          it "returns nil" do
            model.to_key.should be_nil
          end
        end
      end

      describe "#to_param" do
        context "when persisted" do
          it "returns the guid as a string" do
            model.to_param.should be_a(String)
            model.to_param.should == guid
          end
        end

        context "when not persisted" do
          let(:guid) { nil }

          it "returns nil" do
            model.to_param.should be_nil
          end
        end
      end

      describe "#persisted?" do
        context "on a new object" do
          let(:guid) { nil }
          it "returns false" do
            model.should_not be_persisted
          end
        end

        context "on an object with a guid" do
          it "returns false" do
            model.should be_persisted
          end
        end

        context "on an object that has been deleted" do
          before do
            client.base.stub(:delete)
            model.delete
          end

          it "returns false" do
            model.should_not be_persisted
          end
        end
      end

      describe "metadata" do
        let(:new_object) { client.test_model }

        context "when metadata are set" do
          it "has timestamps" do
            new_object.created_at.should be_nil
            new_object.updated_at.should be_nil
          end
        end

        context "when metadata are not defined" do
          before do
            new_object.stub(:manifest).with(nil)
          end

          it "returns nil for timestamps" do
            new_object.updated_at.should be_nil
            new_object.updated_at.should be_nil
          end
        end
      end

      describe "creating a new object" do
        let(:new_object) { client.test_model }

        describe "getting attributes" do
          it "does not go to cloud controller" do
            expect {
              new_object.foo
            }.to_not raise_error
          end

          it "remembers set values" do
            new_object.foo = "bar"
            new_object.foo.should == "bar"
          end
        end

        describe "getting associations" do
          describe "to_one associations" do
            it "returns the an empty object of the association's type" do
              new_object.domain.guid.should be_nil
            end
          end
        end
      end

      describe "first_page" do
        before do
          WebMock.stub_request(:get, /v2\/test_models/).to_return(:body => {
              "prev_url" => nil,
              "next_url" => next_url,
              "resources" => [{:metadata => {:guid => '1234'}}]
          }.to_json)
        end

        context "when there is a next page" do
          let(:next_url) { "/v2/test_models?&page=2&results-per-page=50" }
          before do
            WebMock.stub_request(:get, /v2\/test_models/).to_return(:body => {
                "prev_url" => nil,
                "next_url" => "/v2/test_models?&page=2&results-per-page=50",
                "resources" => [{:metadata => {:guid => '1234'}}]
            }.to_json)
          end

          it "has next_page set to true" do
            results = client.test_models_first_page
            results[:next_page].should be_true
            results[:results].length.should == 1
            results[:results].first.should be_a TestModel
          end
        end

        context "when there is no next page" do
          let(:next_url) { nil }

          it "has next_page set to false" do
            results = client.test_models_first_page
            results[:next_page].should be_false
          end
        end
      end

      describe "for_each" do

        before do

          WebMock.stub_request(:get, /v2\/test_models\?inline-relations-depth=1/).to_return(:body => {
            "prev_url" => nil,
            "next_url" => "/v2/test_models?page=2&q=timestamp>2012-11-01T12:00:00Z&results-per-page=50",
            "resources" => [{:metadata => {:guid => '1'}}, {:metadata => {:guid => '2'}}]
          }.to_json).times(1)

          WebMock.stub_request(:get, /v2\/test_models\?page=2&q=timestamp%3E2012-11-01T12:00:00Z&results-per-page=50/).to_return(:body => {
            "prev_url" => nil,
            "next_url" => nil,
            "resources" => [{:metadata => {:guid => '3'}}]
          }.to_json).times(1)
        end

        it "yields each page to the given the block" do
          results = []
          client.test_models_for_each do |test_model|
            results << test_model
          end
          results.collect {|r| r.guid}.should == %w{1 2 3}
          results.first.should be_a TestModel
        end
      end

      describe "#create_endpoint_name" do
        let(:default_model) { DefaultTestModel.new(guid, client, manifest) }

        it "defaults to the plural object name" do
          expect(default_model.create_endpoint_name).to eq(:default_test_models)
        end
      end
    end
  end
end
