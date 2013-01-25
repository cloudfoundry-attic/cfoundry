require "spec_helper"

describe CFoundry::Snapshots::Client do
  let(:target) { "https://api.example.com" }
  let(:gateway_name) { "some-gateway-name" }
  let(:gateway_base) { "#{target}/services/v1/configurations/#{gateway_name}" }

  subject { CFoundry::Snapshots::Client.new target, gateway_name }

  its(:target) { should eq target }

  describe "#create_snapshot" do
    let!(:request) do
      stub_request(:post, "#{gateway_base}/snapshots").with(
        :headers => {"Accept" => "application/json"}
      ).to_return(:body => '{"job_id":"job-id","status":"queued","start_time":"2012-11-21 23:15:31 +0000","description":"None"}')
    end

    it "POSTs to the gateway snapshots URL" do
      subject.create_snapshot
      expect(request).to have_been_requested
    end

    it "returns a Job object" do
      job = subject.create_snapshot
      expect(job).to be_a CFoundry::Snapshots::Job
      expect(job.guid).to eq "job-id"
    end
  end

  describe "#job" do
    let!(:request) do
      stub_request(:get, "#{gateway_base}/jobs/some-job-id").with(
        :headers => {"Accept" => "application/json"}
      ).to_return(:body => '{"job_id":"job-id","status":"queued","start_time":"2012-11-21 23:15:31 +0000","description":"None"}')
    end

    it "GETs the job with the given ID" do
      subject.job("some-job-id")
      expect(request).to have_been_requested
    end

    it "returns a Job manifest" do
      manifest = subject.job("some-job-id")
      expect(manifest).to be_a Hash
      expect(manifest[:job_id]).to eq "job-id"
    end
  end
end