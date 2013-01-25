require "spec_helper"

describe CFoundry::V1::ModelMagic do
  let(:client) { v1_fake_client }
  let(:mymodel) { v1_fake_model }
  let(:guid) { random_string("my-object-guid") }
  let(:myobject) { mymodel.new(guid, client) }

  describe "#read_manifest" do
    context "with an attribute with different read/write locations" do
      let(:mymodel) do
        v1_fake_model do
          attribute :foo, :string, :read => :x, :write => [:y, :z]
        end
      end

      before do
        stub(client.base).my_fake_model { { :x => "abc" } }
      end

      it "reads from the write location" do
        expect {
          myobject.foo = "def"
        }.to change { myobject.read_manifest[:foo] }.from("abc").to("def")
      end
    end
  end

  describe "#write_manifest" do
    context "with a read-only attribute" do
      let(:mymodel) do
        v1_fake_model do
          attribute :foo, :string, :read_only => true
        end
      end

      it "does not include the attribute" do
        myobject.fake(:foo => "bar")
        expect(myobject.write_manifest).to_not include :foo
      end
    end
  end
end
