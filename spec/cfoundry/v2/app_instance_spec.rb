require 'spec_helper'

module CFoundry::V2
  describe AppInstance do
    let(:client) { double }
    let(:guid) { 'a snowflake' }
    let(:name) { 'test-app' }
    let(:instance_json) {
      {
        :state => "RUNNING",
        :since => 1383588787.1809542,
        :debug_ip => nil,
        :debug_port => nil,
        :console_ip => nil,
        :console_port => nil
      }
    }
    describe '.for_app' do
      before do
        instances_json = {:"0" => instance_json}
        client.stub_chain(:base, :instances).and_return instances_json
      end

      it 'returns instances' do
        instances = AppInstance.for_app(name, guid, client)
        expect(instances.count).to eq 1
        expect(instances.first.inspect).to eq "#<App::Instance '#{name}' \#0>"
      end
    end
  end
end
