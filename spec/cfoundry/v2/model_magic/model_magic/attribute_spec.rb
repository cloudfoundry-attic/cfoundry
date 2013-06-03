require "spec_helper"

module CFoundry
  module V2
    describe ModelMagic do
      describe "attributes" do
        let(:guid) { "test-model-guid-1" }
        let(:client) { build(:client) }

        describe "reading" do
          context "when it exists in the manifest" do
            let(:manifest) { {:metadata => {}, :entity => {:foo => "bar"}} }

            let(:model) do
              TestModelBuilder.build(guid, client, manifest) { attribute :foo, :object }
            end

            it "returns the value from the manifest" do
              expect(model.foo).to eq "bar"
            end

            context "and the default is nil but the value is false" do
              let(:model) do
                TestModelBuilder.build(guid, client, manifest) { attribute :foo, :object, :default => nil }
              end

              before do
                model.foo = false
              end

              it "returns false" do
                expect(model.foo).to eq false
              end
            end

            context "and the default is false but the value is nil" do
              let(:model) do
                TestModelBuilder.build(guid, client, manifest) { attribute :foo, :object, :default => false }
              end

              before do
                model.foo = nil
              end

              it "returns nil" do
                expect(model.foo).to eq nil
              end
            end
          end

          context "when the manifest has not been acquired" do
            let(:model) do
              TestModelBuilder.build(guid, client) { attribute :foo, :object }
            end

            it "retrieves the manifest the first time" do
              mock(client.base).test_model("test-model-guid-1") {
                {:entity => {:foo => "fizz"}}
              }.ordered

              expect(model.foo).to eq "fizz"

              dont_allow(client.base).model.ordered

              expect(model.foo).to eq "fizz"
            end
          end

          context "when it does not exist in the manifest" do
            let(:model) do
              TestModelBuilder.build(guid, client, {:entity => {}}) { attribute :foo, :object, :default => "foo" }
            end

            it "returns the default value" do
              expect(model.foo).to eq "foo"
            end
          end

          context "when the attribute has a custom json key" do
            let(:model) do
              TestModelBuilder.build(guid, client) { attribute :foo, :object, :at => :not_foo }
            end

            before do
              stub(client.base).test_model("test-model-guid-1") {
                {:entity => {:not_foo => "fizz"}}
              }
            end

            it "retrieves the attribute using the custom key" do
              expect(model.foo).to eq "fizz"
            end
          end
        end

        describe "writing" do
          context "when the attribute has a custom json key" do
            let(:model) do
              TestModelBuilder.build(guid, client) { attribute :foo, :object, :at => :not_foo }
            end

            it "uses the 'at' value in the update payload" do
              mock(client.base).put("v2", :test_models, model.guid, hash_including(:payload => {:not_foo => 123}))
              model.foo = 123
              model.update!
            end

            it "uses the 'at' value in the create payload" do
              model.foo = 123
              mock(client.base).post("v2", :test_models, hash_including(:payload => {:not_foo => 123})) { {:metadata => {}} }
              model.create!
            end

            it "is then readable via the attribute name" do
              model.foo = 123
              expect(model.foo).to eq 123
            end
          end
        end
      end
    end
  end
end
