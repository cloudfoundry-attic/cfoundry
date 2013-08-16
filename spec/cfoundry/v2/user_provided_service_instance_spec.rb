require 'spec_helper'

module CFoundry
  module V2
    describe UserProvidedServiceInstance do
      let(:client) { build(:client) }
      subject { build(:user_provided_service_instance, :client => client) }

      describe 'space' do
        let(:space) { build(:space) }

        it 'has a space' do
          subject.space = space
          expect(subject.space).to eq(space)
        end

        context 'when an invalid value is assigned' do
          it 'raises a Mismatch exception' do
            expect {
              subject.space = [build(:organization)]
            }.to raise_error(CFoundry::Mismatch)
          end
        end
      end

      describe 'creating' do
        let(:body) {
          {
            'metadata' => {
              'guid' => 'someguid'
            }
          }.to_json
        }

        it 'calls the correct endpoint' do
          stub_request(:any, %r[.*]).
            to_return(:body => body, :status => 200)

          subject.create!

          a_request(:post, 'http://api.example.com/v2/user_provided_service_instances').should have_been_made
        end
      end

      describe 'deleting' do
        it 'calls the correct endpoint' do
          stub_request(:any, %r[.*])

          subject.delete!

          a_request(:delete, "http://api.example.com/v2/service_instances/#{subject.guid}").should have_been_made
        end
      end
    end
  end
end

