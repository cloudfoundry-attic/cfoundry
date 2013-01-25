require "spec_helper"

describe CFoundry::Snapshots::Job do
  let(:job_hash) do
    {
      :job_id => "123",
      :status => "queued",
      :start_time => "2012-11-21 23:15:31 +0000",
      :description => "None"
    }
  end

  let(:client) { CFoundry::Snapshots::Client.new "https://api.example.com", nil }

  subject { CFoundry::Snapshots::Job.new(job_hash, client) }

  describe ".new" do
    its(:class) { should eq described_class }
    its(:guid) { should eq "123" }
    its(:description) { should eq "None" }
    its(:status) { should eq "queued" }
    its(:start_time) { should eq DateTime.new(2012, 11, 21, 23, 15, 31) }
  end

  describe "#wait" do
    context "after waiting ended successfully" do
      let(:queued_response) { job_hash }
      let(:finished_response) { job_hash.merge(:status => "completed", :result => { "foo" => "bar" }) }

      before do
        mock(client).job("123") { queued_response }.ordered
        mock(client).job("123") { queued_response }.ordered
        mock(client).job("123") { queued_response }.ordered
        mock(client).job("123") { finished_response }.ordered

        stub(subject).sleep(anything)
      end

      it "updates it's status" do
        subject.wait
        expect(subject.status).to eq "completed"
      end

      it "contains the result" do
        subject.wait
        expect(subject.result).to eq("foo" => "bar")
      end

      it "polls periodically" do
        mock(subject).sleep(1)
        subject.wait
      end

      it "accepts polling interval" do
        mock(subject).sleep(42)
        subject.wait(:interval => 42)
      end

      it "times out after a given timeout" do
        mock(Timeout).timeout(5) { |_, blk| blk.call }
        subject.wait(:timeout => 5)
      end

      it "times out by default" do
        mock(Timeout).timeout(60) { |_, blk| blk.call }
        subject.wait
      end
    end
  end
end
