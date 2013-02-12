require "spec_helper"

describe CFoundry::V2::App do
  let(:client) { fake_client }

  describe "environment" do
    let(:app) { fake :app, :env => { "FOO" => "1" } }

    it "returns a hash-like object" do
      expect(app.env["FOO"]).to eq "1"
    end

    describe "converting keys and values to strings" do
      let(:app) { fake :app, :env => { :FOO => 1 } }

      it "converts keys and values to strings" do
        expect(app.env.to_hash).to eq("FOO" => "1")
      end
    end

    context "when changes are made to the hash-like object" do
      it "reflects the changes in .env" do
        expect {
          app.env["BAR"] = "2"
        }.to change { app.env.to_hash }.from("FOO" => "1").to("FOO" => "1", "BAR" => "2")
      end
    end

    context "when the env is set to something else" do
      it "reflects the changes in .env" do
        expect {
          app.env = { "BAR" => "2" }
        }.to change { app.env.to_hash }.from("FOO" => "1").to("BAR" => "2")
      end
    end
  end

  describe "#summarize!" do
    let(:app) { fake :app }

    it "assigns :instances as #total_instances" do
      stub(app).summary { { :instances => 4 } }

      app.summarize!

      expect(app.total_instances).to eq(4)
    end
  end
end
