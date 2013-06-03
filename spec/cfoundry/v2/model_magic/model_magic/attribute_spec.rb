require "spec_helper"

class TestModel < CFoundry::V2::Model
end

def create_test_model(guid, client, manifest=nil, &init)
  klass = TestModel.new(guid, client, manifest)
  klass.class_eval(&init) if init
  klass
end

module CFoundry
  module V2
    describe ModelMagic do
      describe "attributes" do
        let(:guid) { "test-model-guid-1" }
        let(:client) { build(:client) }

        describe "reading" do
          let(:mymodel) do
            create_test_model(guid, client) { attribute :foo, :object }
          end

          context "when it exists in the manifest" do
            let(:manifest) { {:entity => {:foo => "bar"}} }

            subject do
              create_test_model(guid, client, manifest) { attribute :foo, :object }
            end

            it "returns the value from the manifest" do
              expect(subject.foo).to eq "bar"
            end

            context "and the default is nil but the value is false" do
              let(:mymodel) do
                create_test_model(guid, client) { attribute :foo, :object, :default => nil }
              end

              before do
                mymodel.foo = false
              end

              subject { mymodel }

              it "returns false" do
                expect(subject.foo).to eq false
              end
            end

            context "and the default is false but the value is nil" do
              let(:mymodel) {
                create_test_model(guid, client) { attribute :foo, :object, :default => false}
              }

              before do
                mymodel.foo = nil
              end

              subject { mymodel }

              it "returns nil" do
                expect(subject.foo).to eq nil
              end
            end
          end

          context "when the manifest has not been acquired" do
            it "retrieves the manifest the first time" do
              mock(client.base).test_model("test-model-guid-1") {
                {:entity => {:foo => "fizz"}}
              }.ordered

              expect(mymodel.foo).to eq "fizz"

              dont_allow(client.base).mymodel.ordered

              expect(mymodel.foo).to eq "fizz"
            end
          end

          context "when it does not exist in the manifest" do
            let(:mymodel) {
              create_test_model(guid, client, {:entity => {}}) { attribute :foo, :object, :default => "foo" }
            }

            subject { mymodel }

            it "returns the default value" do
              expect(subject.foo).to eq "foo"
            end
          end

          context "when the attribute has a custom json key" do
            let(:mymodel) {
              create_test_model(guid, client) { attribute :foo, :object, :at => :not_foo }
            }

            subject { mymodel }

            it "retrieves the attribute using the custom key" do
              stub(client.base).test_model("test-model-guid-1") {
                {:entity => {:not_foo => "fizz"}}
              }

              expect(subject.foo).to eq "fizz"
            end
          end
        end

        describe "writing" do
          context "when the attribute has a custom json key" do
            let(:mymodel) {
              create_test_model(guid, client) { attribute :foo, :object, :at => :not_foo }
            }

            subject { mymodel }

            it "uses the 'at' value in the update payload" do
              mock(client.base).put("v2", :test_models, subject.guid, hash_including(:payload => {:not_foo => 123}))
              subject.foo = 123
              subject.update!
            end

            it "uses the 'at' value in the create payload" do
              subject.foo = 123

              mock(client.base).post(
                "v2", :test_models,
                hash_including(:payload => {:not_foo => 123})
              ) { {:metadata => {}} }

              subject.create!
            end

            it "is then readable via the attribute name" do
              subject.foo = 123
              expect(subject.foo).to eq 123
            end
          end
        end
      end
    end
  end
end
