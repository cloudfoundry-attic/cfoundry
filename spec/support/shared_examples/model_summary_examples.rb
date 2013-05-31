require "multi_json"

shared_examples_for "a summarizeable model" do
  describe "#summary" do
    let(:summary_endpoint) {
      [ client.target,
        "v2",
        subject.class.plural_object_name,
        subject.guid,
        "summary"
      ].join("/")
    }

    it "returns the summary endpoint payload" do
      req = stub_request(:get, summary_endpoint).to_return :status => 200,
        :body => MultiJson.encode(summary_attributes)

      expect(subject.summary).to eq(summary_attributes)
      expect(req).to have_been_requested
    end
  end

  describe "#summarize!" do
    it "defines basic attributes via #summary" do
      stub(subject).summary { summary_attributes }

      subject.summarize!

      summary_attributes.each do |k, v|
        expect(subject.send(k)).to eq v
      end
    end
  end
end
