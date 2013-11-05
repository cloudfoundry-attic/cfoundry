require "spec_helper"

module CFoundry
  module V2
    describe App do
      let(:client) { build(:client) }

      subject { build(:app, :client => client, :name => 'foo-app') }

      describe "#events" do
        let(:events) { [build(:app_event)] }

        it "has events" do
          subject.events = events
          expect(subject.events).to eq(events)
        end

        context "when an invalid value is assigned" do
          it "raises a Mismatch exception" do
            expect {
              subject.events = [build(:organization)]
            }.to raise_error(CFoundry::Mismatch)
          end
        end
      end

      describe "environment" do
        let(:app) { build(:app, :env => {"FOO" => "1"}) }

        it "returns a hash-like object" do
          expect(app.env["FOO"]).to eq "1"
        end

        describe "converting keys and values to strings" do
          let(:app) { build(:app, :env => {:FOO => 1}) }

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
              app.env = {"BAR" => "2"}
            }.to change { app.env.to_hash }.from("FOO" => "1").to("BAR" => "2")
          end
        end
      end

      describe "#summarize!" do
        let(:app) { build(:app) }

        it "assigns :instances as #total_instances" do
          app.stub(:summary) { {:instances => 4} }

          app.summarize!

          expect(app.total_instances).to eq(4)
        end
      end

      shared_examples_for "something may stage the app" do
        subject { build(:app, :client => client) }
        let(:response) { {:body => '{ "foo": "bar" }'} }

        before do
          client.base.stub(:put).with("v2", "apps", subject.guid, anything) do
            response
          end
        end

        it "sends the PUT request" do
          client.base.should_receive(:put).with(
            "v2", "apps", subject.guid,
            hash_including(
              :return_response => true)) do
            response
          end

          update
        end

        context "and a block is given" do
          let(:response) do
            { :headers => { "x-app-staging-log" => "http://app/staging/log" },
              :body => "{}"
            }
          end

          it "yields the URL for the logs" do
            yielded_url = nil
            update do |url|
              yielded_url = url
            end

            expect(yielded_url).to eq "http://app/staging/log"
          end

          context "and no staging header is returned" do
            let(:response) do
              { :headers => {},
                :body => "{}"
              }
            end

            it "yields nil" do
              yielded_url = :something
              update do |url|
                yielded_url = url
              end

              expect(yielded_url).to be_nil
            end
          end
        end
      end

      describe "#start!" do
        it_should_behave_like "something may stage the app" do
          def update(&blk)
            subject.start!(&blk)
          end
        end
      end

      describe "#restart!" do
        it_should_behave_like "something may stage the app" do
          def update(&blk)
            subject.restart!(&blk)
          end
        end
      end

      describe "#update!" do
        describe "changes" do
          subject { build(:app, :client => client) }
          let(:response) { {:body => {"foo" => "bar"}.to_json} }

          before do
            client.base.stub(:put).with("v2", "apps", subject.guid, anything) do
              response
            end
          end

          it "applies the changes from the response JSON" do
            expect {
              subject.update!
            }.to change { subject.manifest }.to(:foo => "bar")
          end
        end

        it_should_behave_like "something may stage the app" do
          def update(&blk)
            subject.update!(&blk)
          end
        end
      end

      describe "#stream_update_log" do
        let(:base_url) { "http://example.com/log" }

        def mock_log(url = anything)
          client.should_receive(:stream_url).with(url) do |_, &blk|
            blk.call(yield)
          end.ordered
        end

        def stub_log(url = anything)
          client.stub(:stream_url).with(url) do |_, blk|
            blk.call(yield)
          end.ordered
        end

        it "yields chunks from the response to the block" do
          mock_log { "a" }
          mock_log { "b" }
          mock_log { raise CFoundry::NotFound }

          chunks = []
          subject.stream_update_log(base_url) do |chunk|
            chunks << chunk
          end

          expect(chunks).to eq(%w(a b))
        end

        it "retries when the connection times out" do
          mock_log { raise ::Timeout::Error }
          mock_log { "a" }
          mock_log { raise ::Timeout::Error }
          mock_log { "b" }
          mock_log { raise ::Timeout::Error }
          mock_log { raise CFoundry::NotFound }

          chunks = []
          subject.stream_update_log(base_url) do |chunk|
            chunks << chunk
          end

          expect(chunks).to eq(%w(a b))
        end

        it "tracks the offset to stream from" do
          url = "#{base_url}&tail&tail_offset="

          mock_log("#{url}0") { "a" }
          mock_log("#{url}1") { raise ::Timeout::Error }
          mock_log("#{url}1") { "b" }
          mock_log("#{url}2") { raise CFoundry::NotFound }

          chunks = []
          subject.stream_update_log(base_url) do |chunk|
            chunks << chunk
          end

          expect(chunks).to eq(%w(a b))
        end

        it "stops when the endpoint disappears" do
          mock_log { "a" }
          mock_log { "b" }
          mock_log { raise CFoundry::NotFound }
          stub_log { "c" }

          chunks = []
          subject.stream_update_log(base_url) do |chunk|
            chunks << chunk
          end

          expect(chunks).to eq(%w(a b))
        end
      end

      describe "delete!" do
        it "defaults to recursive" do
          client.base.should_receive(:delete).with("v2", :apps, subject.guid, {:params => {:recursive => true}})

          subject.delete!
        end
      end

      it "accepts and ignores an options hash" do
        client.base.should_receive(:delete).with("v2", :apps, subject.guid, {:params => {:recursive => true}})

        subject.delete!(:recursive => false)
      end

      describe "#health" do
        describe "when staging failed for an app" do
          it "returns 'STAGING FAILED' as state" do
            AppInstance.stub(:for_app) { raise CFoundry::StagingError }
            subject.stub(:state) { "STARTED" }

            expect(subject.health).to eq("STAGING FAILED")
          end
        end
      end

      describe "#percent_running" do
        before do
          subject.stub(:state) { "STARTED" }
          subject.total_instances = instances.count
          AppInstance.stub(:for_app).with(subject.name, subject.guid, client) { instances }
        end

        let(:instances) do
          (1..3).map { double(AppInstance, state: "RUNNING") }
        end

        it "returns the percent of instances running as an integer" do
          expect(subject.percent_running).to eq(100)
        end

        context "when half the instances are running" do
          let(:instances) { [double(AppInstance, state: "RUNNING"), double(AppInstance, state: "STOPPED")] }

          it "returns 50" do
            expect(subject.percent_running).to eq(50)
          end
        end

        context "when staging has failed" do
          before { AppInstance.stub(:for_app) { raise CFoundry::StagingError } }

          it "returns 0" do
            expect(subject.percent_running).to eq(0)
          end
        end
      end

      describe "#host" do
        let(:route) { build(:route, :host => "my-host") }
        let(:app) { build(:app) }

        context "when at least one route exists" do
          it "returns the host that the user has specified" do
            app.stub(:routes).and_return([route])
            expect(app.host).to eq("my-host")
          end
        end

        context "when no routes exists" do
          it "returns the host that the user has specified" do
            app.stub(:routes).and_return([])
            expect(app.host).to be_nil
          end
        end
      end

      describe "#domain" do
        let(:domain) { build(:domain, :name => "my-domain") }
        let(:route) { build(:route, :domain => domain) }
        let(:app) { build(:app) }

        context "when at least one route exists" do
          it "returns the domain that the user has specified" do
            app.stub(:routes).and_return([route])
            expect(app.domain).to eq("my-domain")
          end
        end

        context "when no routes exists" do
          it "returns the domain that the user has specified" do
            app.stub(:routes).and_return([])
            expect(app.domain).to be_nil
          end
        end
      end

      describe "#uri" do
        context "when there are one or more routes" do
          let(:domain) { build(:domain, :name => "example.com") }
          let(:route) { build(:route, :host => "my-host", :domain => domain) }
          let(:other_route) { build(:route, :host => "other-host", :domain => domain) }
          let(:app) { build(:app) }

          it "return the first one" do
            app.stub(:routes).and_return([route, other_route])
            expect(app.uri).to eq("#{route.host}.#{route.domain.name}")
          end
        end
      end
    end
  end
end
