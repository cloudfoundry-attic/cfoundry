require "spec_helper"

describe CFoundry::V2::Model do
  let(:client) { fake_client }
  let(:guid) { random_string("my-object-guid") }
  let(:manifest) { {:metadata => {:foo => "bar"}} }
  let(:klass) {
    fake_model do
      attribute :foo, :string, :read => :x, :write => [:y, :z]
    end
  }

  subject { klass.new(guid, client, manifest) }

  describe "#create!" do
    before do
      stub(client.base).post {
        {:metadata => {:guid => "123"}}
      }
      subject.foo = "bar"
    end

    it "posts to the model's create url with appropriate arguments" do
      mock(client.base).post("v2", :my_fake_models,
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
      subject.foo = "bar"
    end

    it "updates using the client with the v2 api, its plural model name, object guid, and diff object" do
      mock(client.base).put("v2", :my_fake_models, guid,
        :content => :json,
        :accept => :json,
        :payload => {:foo => "bar"}
      )
      subject.update!
    end

    it "clears diff" do
      subject.diff.should be_present
      subject.update!
      subject.diff.should_not be_present
    end
  end

  describe "#delete!" do
    before { stub(client.base).delete }

    context "without options" do
      it "deletes using the client with the v2 api, its plural model name, object guid, and empty params hash" do
        mock(client.base).delete("v2", :my_fake_models, guid, :params => {})
        subject.delete!
      end
    end

    context "with options" do
      it "sends delete with the object guid and options" do
        options = {:excellent => "billandted"}
        mock(client.base).delete("v2", :my_fake_models, guid, :params => options)

        subject.delete!(options)
      end
    end

    it "clears its guid" do
      subject.guid.should be_present
      subject.delete!
      subject.guid.should_not be_present
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
end
