require "spec_helper"

module CFoundry
  module V2
    describe App do
      let(:client) { build(:client) }

      subject { build(:app, :client => client) }

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
          stub(app).summary { {:instances => 4} }

          app.summarize!

          expect(app.total_instances).to eq(4)
        end
      end

      shared_examples_for "something may stage the app" do
        subject { build(:app, :client => client) }
        let(:response) { {:body => '{ "foo": "bar" }'} }

        before do
          stub(client.base).put("v2", "apps", subject.guid, anything) do
            response
          end
        end

        context "when asynchronous is true" do
          it "sends the PUT request with &stage_async=true" do
            mock(client.base).put(
              "v2", "apps", subject.guid,
              hash_including(
                :params => {:stage_async => true},
                :return_response => true)) do
              response
            end

            update(true)
          end

          context "and a block is given" do
            let(:response) do
              {:headers => {"x-app-staging-log" => "http://app/staging/log"},
                :body => "{}"
              }
            end

            it "yields the URL for the logs" do
              yielded_url = nil
              update(true) do |url|
                yielded_url = url
              end

              expect(yielded_url).to eq "http://app/staging/log"
            end
          end
        end

        context "when asynchronous is false" do
          it "sends the PUT request with &stage_async=false" do
            mock(client.base).put(
              "v2", "apps", subject.guid,
              hash_including(:params => {:stage_async => false})) do
              response
            end

            update(false)
          end
        end
      end

      describe "#start!" do
        it_should_behave_like "something may stage the app" do
          def update(async, &blk)
            subject.start!(async, &blk)
          end
        end
      end

      describe "#restart!" do
        it_should_behave_like "something may stage the app" do
          def update(async, &blk)
            subject.restart!(async, &blk)
          end
        end
      end

      describe "#update!" do
        describe "changes" do
          subject { build(:app, :client => client) }
          let(:response) { {:body => { "foo" => "bar" }.to_json } }

          before do
            stub(client.base).put("v2", "apps", subject.guid, anything) do
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
          def update(async, &blk)
            subject.update!(async, &blk)
          end
        end
      end

      describe "#stream_update_log" do
        let(:base_url) { "http://example.com/log" }

        def mock_log(url = anything)
          mock(client).stream_url(url) do |_, blk|
            blk.call(yield)
          end.ordered
        end

        def stub_log(url = anything)
          stub(client).stream_url(url) do |_, blk|
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
          mock(client.base).delete("v2", :apps, subject.guid, {:params => {:recursive => true}})

          subject.delete!
        end
      end

      it "accepts and ignores an options hash" do
        mock(client.base).delete("v2", :apps, subject.guid, {:params => {:recursive => true}})

        subject.delete!(:recursive => false)
      end
    end
  end
end
