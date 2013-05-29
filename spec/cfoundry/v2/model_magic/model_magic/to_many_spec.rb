require "spec_helper"

module CFoundry::V2
  include ModelMagic::ToMany
  
  class AssociatedModel < FakeModel
    attribute :attribute, String
  end

  describe ModelMagic::ToMany do
    let(:client) { fake_client }
    let(:mymodel) { fake_model }
    let(:guid) { random_string("my-object-guid") }
    let(:myobject) { mymodel.new(guid, client) }

    describe "to_many relationships" do
      describe "associated create" do
        let!(:model) { fake_model { to_many :associated_models } }
        let(:instance) { model.new(nil, client).fake }
        let!(:create_request) { WebMock.stub_request(:post, /v2\/associated_model/).to_return(:body => {:metadata => {:guid => "thing"}}.to_json) }
        let!(:add_request) { WebMock.stub_request(:put, /v2\/my_fake_models\/.*\/associated_models/).to_return(:body => {}.to_json) }

        before do
          stub_request(:get, /v2\/my_fake_models\/.*\/associated_models/)
          instance.associated_models = []
        end

        it "returns a new associated object" do
          instance.create_associated_model.should be_a(AssociatedModel)
        end

        it "sets the relation" do
          created = instance.create_associated_model
          instance.associated_models.should include(created)
        end

        context "with attributes for the association" do
          it "sets these attributes on the association" do
            created = instance.create_associated_model(:attribute => "value")
            created.attribute.should == "value"
          end
        end

        it "calls out to cloud_controller" do
          instance.create_associated_model
          create_request.should have_been_requested
        end

        context "when creation fails" do
          let!(:create_request) { WebMock.stub_request(:post, /v2\/associated_model/).to_raise(:not_authorized) }

          it "raises an exception" do
            expect { instance.create_associated_model }.to raise_error(StandardError)
          end
        end
      end
    end
  end
end