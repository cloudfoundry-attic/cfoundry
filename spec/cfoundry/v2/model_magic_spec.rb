require "spec_helper"

describe CFoundry::V2::ModelMagic do
  let(:client) { fake_client }
  let(:mymodel) { fake_model }
  let(:guid) { random_string("my-object-guid") }
  let(:myobject) { mymodel.new(guid, client) }

  describe 'attributes' do
    describe 'reading' do
      let(:mymodel) { fake_model { attribute :foo, :object } }

      context 'when it exists in the manifest' do
        subject { myobject.fake(:foo => "bar") }

        it 'returns the value from the manifest' do
          expect(subject.foo).to eq "bar"
        end

        context 'and the default is nil but the value is false' do
          let(:mymodel) {
            fake_model { attribute :foo, :object, :default => nil }
          }

          subject { myobject.fake(:foo => false) }

          it 'returns false' do
            expect(subject.foo).to eq false
          end
        end

        context 'and the default is false but the value is nil' do
          let(:mymodel) {
            fake_model { attribute :foo, :object, :default => false }
          }

          subject { myobject.fake(:foo => nil) }

          it 'returns nil' do
            expect(subject.foo).to eq nil
          end
        end
      end

      context 'when the manifest has not been acquired' do
        it 'retrieves the manifest the first time' do
          mock(client.base).my_fake_model(guid) {
            { :entity => { :foo => "fizz" } }
          }.ordered

          expect(myobject.foo).to eq "fizz"

          dont_allow(client.base).my_fake_model.ordered

          expect(myobject.foo).to eq "fizz"
        end
      end

      context 'when it does not exist in the manifest' do
        let(:mymodel) {
          fake_model { attribute :foo, :object, :default => "foo" }
        }

        subject { myobject.fake }

        it 'returns the default value' do
          expect(subject.foo).to eq "foo"
        end
      end
    end
  end

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
  end

  describe 'summarization for an arbitrary model' do
    let(:mymodel) { fake_model { attribute :foo, :string } }
    let(:summary_attributes) { { :foo => "abcd" } }

    subject { myobject }

    it_behaves_like 'a summarizeable model'
  end
end
