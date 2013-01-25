require "spec_helper"

describe CFoundry::Snapshots::Snapshot do
  describe ".new" do
    let(:snapshot_hash) do
      {
        :date => "2013-01-23T19:31:06Z",
        :snapshot_id => "125",
        :size => 491,
        :name => "Snapshot Name"
      }
    end

    subject { CFoundry::Snapshots::Snapshot.new(snapshot_hash, nil) }

    its(:class) { should eq described_class }
    its(:guid) { should eq "125" }
    its(:name) { should eq "Snapshot Name" }
    its(:size) { should eq 491 }
    its(:created_at) { should eq DateTime.new(2013, 1, 23, 19, 31, 6) }
  end
end