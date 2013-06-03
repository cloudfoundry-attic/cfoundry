require "spec_helper"

class TestModel < CFoundry::V2::Model
  attribute :foo, :string
  to_one :domain
end

module CFoundry
  module V2
    describe Model do
      let(:client) { build(:client) }
      let(:guid) { random_string("my-object-guid") }
      let(:manifest) { {:metadata => {:foo => "bar"}} }

      subject { TestModel.new(guid, client, manifest) }

      describe "create" do
        it "uses #create!" do
          mock(subject).create!
          subject.create
        end

        context "without errors" do
          it "returns true" do
            mock(subject).create!
            subject.create.should == true
          end
        end

        context "with errors" do
          before do
            stub(subject.class).model_name { ActiveModel::Name.new(subject, nil, "abstract_model") }
            stub(subject).create! { raise CFoundry::APIError.new("HELP") }
          end

          it "does not raise an exception" do
            expect { subject.create }.to_not raise_error
          end

          it "returns false" do
            subject.create.should == false
          end

          context "without model-specific errors" do
            it "adds generic base error " do
              subject.create
              subject.errors.full_messages.first.should =~ /cloud controller reported an error/i
            end
          end

          context "with model-specific errors" do
            it "does not set the generic error on base" do
              subject.create
              subject.errors.size.should == 1
            end
          end
        end
      end

      describe "#create!" do
        before do
          stub(client.base).post {
            {:metadata => {:guid => "123"}}
          }
          subject.foo = "bar"
        end

        it "posts to the model's create url with appropriate arguments" do
          mock(client.base).post("v2", :test_models,
            :content => :json,
            :accept => :json,
            :payload => {:foo => "bar"}
          ) { {:metadata => {}} }
          subject.create!
        end

        it "clears diff" do
          subject.diff.should be_present
          subject.create!
          subject.diff.should_not be_present
        end

        it "sets manifest from the response" do
          subject.create!
          subject.manifest.should == {:metadata => {:guid => "123"}}
        end

        it "sets guid from the response metadata" do
          subject.create!
          subject.guid.should == "123"
        end
      end

      describe "#update!" do
        before do
          stub(client.base).put
        end

        it "updates using the client with the v2 api, its plural model name, object guid, and diff object" do
          subject.foo = "bar"

          mock(client.base).put("v2", :test_models, guid,
            :content => :json,
            :accept => :json,
            :payload => {:foo => "bar"}
          )
          subject.update!
        end

        it "clears diff" do
          subject.foo = "bar"

          subject.diff.should be_present
          subject.update!
          subject.diff.should_not be_present
        end
      end

      describe "delete" do
        it "uses #delete!" do
          mock(subject).delete!({}) { true }
          subject.delete
        end

        it "passes options along to delete!" do
          mock(subject).delete!(:recursive => true) { true }
          subject.delete(:recursive => true)
        end

        context "without errors" do
          it "returns true" do
            mock(subject).delete!({}) { true }
            subject.delete.should == true
          end
        end

        context "with errors" do
          before do
            stub(subject.class).model_name { ActiveModel::Name.new(subject, nil, "abstract_model") }
            stub(subject).delete! { raise CFoundry::APIError.new("HELP") }
          end

          it "does not raise an exception" do
            expect { subject.delete }.to_not raise_error
          end

          it "returns false" do
            subject.delete.should == false
          end

          context "without model-specific errors" do
            it "adds generic base error " do
              subject.delete
              subject.errors.full_messages.first.should =~ /cloud controller reported an error/i
            end
          end

          context "with model-specific errors" do
            it "does not set the generic error on base" do
              subject.delete
              subject.errors.size.should == 1
            end
          end
        end
      end

      describe "#delete!" do
        before { stub(client.base).delete }

        context "without options" do
          it "deletes using the client with the v2 api, its plural model name, object guid, and empty params hash" do
            mock(client.base).delete("v2", :test_models, guid, :params => {})
            subject.delete!
          end
        end

        context "with options" do
          it "sends delete with the object guid and options" do
            options = {:excellent => "billandted"}
            mock(client.base).delete("v2", :test_models, guid, :params => options)

            subject.delete!(options)
          end
        end

        it "clears its manifest metadata" do
          subject.manifest.should have_key(:metadata)
          subject.delete!
          subject.manifest.should_not have_key(:metadata)
        end

        it "clears the diff" do
          subject.foo = "bar"
          subject.diff.should be_present
          subject.delete!
          subject.diff.should_not be_present
        end

        it "delete me" do
          begin
            subject.delete!
          rescue => ex
            ex.message.should_not =~ /\?/
          end
        end
      end

      describe "#to_key" do
        context "when persisted" do
          it "returns an enumerable containing the guid" do
            subject.to_key.should respond_to(:each)
            subject.to_key.first.should == guid
          end
        end

        context "when not persisted" do
          let(:guid) { nil }

          it "returns nil" do
            subject.to_key.should be_nil
          end
        end
      end

      describe "#to_param" do
        context "when persisted" do
          it "returns the guid as a string" do
            subject.to_param.should be_a(String)
            subject.to_param.should == guid
          end
        end

        context "when not persisted" do
          let(:guid) { nil }

          it "returns nil" do
            subject.to_param.should be_nil
          end
        end
      end

      describe "#persisted?" do
        context "on a new object" do
          let(:guid) { nil }
          it "returns false" do
            subject.should_not be_persisted
          end
        end

        context "on an object with a guid" do
          it "returns false" do
            subject.should be_persisted
          end
        end

        context "on an object that has been deleted" do
          before do
            stub(client.base).delete
            subject.delete
          end

          it "returns false" do
            subject.should_not be_persisted
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
    end
  end
end
