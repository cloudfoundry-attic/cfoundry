require "spec_helper"

class AssociatedModel < CFoundry::V2::Model
  attribute :attribute, String
end

module CFoundry
  module V2
    module ModelMagic
      describe ToMany do
        let(:client) { build(:client) }

        describe "to_many relationships" do
          describe "associated create" do
            let(:model) do
              TestModelBuilder.build("test-model-guid-1", client) { to_many :associated_models }
            end

            before do
              WebMock.stub_request(:put, /v2\/test_models\/.*\/associated_models/).to_return(:body => {}.to_json)
              WebMock.stub_request(:post, /v2\/associated_model/).to_return(:body => {:metadata => {:guid => "thing"}}.to_json)
              stub_request(:get, /v2\/test_models\/.*\/associated_models/)
              model.associated_models = []
            end

            it "returns a new associated object" do
              model.create_associated_model.should be_a(AssociatedModel)
            end

            it "sets the relation" do
              created = model.create_associated_model
              model.associated_models.should include(created)
            end

            context "with attributes for the association" do
              it "sets these attributes on the association" do
                created = model.create_associated_model(:attribute => "value")
                created.attribute.should == "value"
              end
            end

            context "when creation fails" do
              it "raises an exception" do
                WebMock.stub_request(:post, /v2\/associated_model/).to_raise(:not_authorized)
                expect { model.create_associated_model }.to raise_error(StandardError)
              end
            end
          end
        end
      end
    end
  end
end
