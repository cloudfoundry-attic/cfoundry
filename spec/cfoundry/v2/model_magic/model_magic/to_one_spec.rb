require "spec_helper"

module CFoundry::V2
  include ModelMagic::ToOne
  class Associated < FakeModel
    attribute :attribute, String
  end

  describe ModelMagic::ToOne do
    let(:client) { fake_client }
    let(:mymodel) { fake_model }
    let(:guid) { random_string("my-object-guid") }
    let(:myobject) { mymodel.new(guid, client) }

    describe 'to_one relationships' do
      describe 'writing' do
        let!(:mymodel) { fake_model { to_one :foo } }
        let!(:othermodel) { fake_model :foo }

        let(:myobject) { mymodel.new(nil, client).fake }
        let(:otherobject) { othermodel.new(nil, client).fake }

        subject { myobject.foo = otherobject }

        it "sets the GUID in the manifest to the object's GUID" do
          expect { subject }.to change {
            myobject.manifest[:entity][:foo_guid]
          }.to(otherobject.guid)
        end

        it "tracks internal changes in the diff" do
          expect { subject }.to change { myobject.diff }.to(
            :foo_guid => otherobject.guid)
        end

        it "tracks high-level changes in .changes" do
          before = myobject.foo
          expect { subject }.to change { myobject.changes }.to(
            :foo => [before, otherobject])
        end

        it "returns the assigned value" do
          myobject.send(:foo=, otherobject).should == otherobject
        end

        context "when there is a default" do
          let(:mymodel) { fake_model { to_one :foo, :default => nil } }

          subject { myobject.foo = nil }

          it "allows setting to the default" do
            myobject.foo = otherobject

            expect { subject }.to change {
              myobject.manifest[:entity][:foo_guid]
            }.from(otherobject.guid).to(nil)
          end
        end
      end

      describe 'associated create' do
        let!(:model) { fake_model { to_one :associated } }
        let(:instance) { model.new(nil, client).fake }
        let!(:request) { WebMock.stub_request(:post, /v2\/associated/).to_return(:body => {:metadata => {:guid => "thing"}}.to_json) }

        it 'returns a new associated object' do
          instance.create_associated.should be_a(Associated)
        end

        it 'sets the relation' do
          created = instance.create_associated
          instance.associated.should == created
        end

        context 'with attributes for the association' do
          it 'sets these attributes on the association' do
            created = instance.create_associated(:attribute => 'value')
            created.attribute.should == 'value'
          end
        end

        it 'calls out to cloud_controller' do
          instance.create_associated
          request.should have_been_requested
        end

        context 'when creation fails' do
          let!(:request) { WebMock.stub_request(:post, /v2\/associated/).to_raise(:not_authorized) }

          it 'raises an exception' do
            expect { instance.create_associated }.to raise_error(StandardError)
          end
        end
      end
    end
  end
end