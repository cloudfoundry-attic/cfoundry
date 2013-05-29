require "spec_helper"

module CFoundry::V2
  describe ModelMagic do
    let(:client) { fake_client }
    let(:guid) { random_string("my-object-guid") }
    let(:myobject) { mymodel.new(guid, client) }

    describe 'summarization for an arbitrary model' do
      let(:mymodel) { fake_model { attribute :foo, :string } }
      let(:summary_attributes) { {:foo => "abcd"} }

      subject { myobject }

      it_behaves_like 'a summarizeable model'
    end
  end
end
