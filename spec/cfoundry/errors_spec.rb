require 'spec_helper'

describe 'Errors' do
  describe CFoundry::Timeout do
    let(:parent) { Timeout::Error.new }

    subject { CFoundry::Timeout.new(Net::HTTP::Post, '/blah', parent) }

    its(:to_s) { should eq "POST /blah timed out" }
    its(:method) { should eq Net::HTTP::Post }
    its(:uri) { should eq '/blah' }
    its(:parent) { should eq parent }
  end
end
