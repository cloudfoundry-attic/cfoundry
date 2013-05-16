require 'spec_helper'

describe CFoundry::Validator do
  subject { described_class }

  describe 'value_matches?' do
    it 'returns true on nil values' do
      subject.value_matches?(nil, :something).should be_true
    end

    context 'with a type of Class' do
      it 'returns true when value is of type class' do
        subject.value_matches?(1, Integer).should be_true
      end
    end

    context 'with a Regex' do
      it 'returns true when the regex matches' do
        subject.value_matches?('value', /lue/).should == true
      end
    end

    context 'with type of url' do
      it 'requires http or https urls' do
        subject.value_matches?('http:whatever', :url).should be_true
        subject.value_matches?('https:whatever', :url).should be_true
        subject.value_matches?('htt_no:whatever', :url).should be_false
      end
    end

    context 'with type of https_url' do
      it 'requires http or https urls' do
        subject.value_matches?('https:whatever', :https_url).should be_true
        subject.value_matches?('http:whatever', :https_url).should be_false
      end
    end

    context 'with type boolean' do
      it 'returns true on presence of true or false' do
        subject.value_matches?(true, :boolean).should be_true
        subject.value_matches?(false, :boolean).should be_true
        subject.value_matches?('no boolean', :boolean).should be_false
      end
    end

    context 'with an Array' do
      it 'returns true when all elements are of same type' do
        subject.value_matches?(['https:whatever'], [String]).should be_true
        subject.value_matches?(['https:whatever'], [Integer]).should be_false
      end
    end

    context 'with a hash' do
      it 'returns true when specified types match' do
        subject.value_matches?({:name => "thing"}, {:name => String}).should be_true
        subject.value_matches?({:name => "thing", :unspecified => 1}, {:name => String}).should be_true
        subject.value_matches?({:name => 1}, {:name => String}).should be_false
      end
    end

    it 'returns true when type is nil' do
      subject.value_matches?('some value', nil).should be_true
    end

    context 'with a symbol' do
      it 'returns true when the value is of specified type' do
        subject.value_matches?('some value', :string).should be_true
        subject.value_matches?('some value', :integer).should be_false
      end
    end
  end

  describe 'validate_type' do
    it 'passes validation with a nil value' do
      expect {
      subject.validate_type(nil, :whatever)
      }.to_not raise_error
    end

    it 'passes validation when the value matches' do
      expect {
        subject.validate_type('string', :string)
      }.to_not raise_error
    end

    it 'raises a validation error when value does not match' do
      expect {
        subject.validate_type('string', :integer)
      }.to raise_error(CFoundry::Mismatch)
    end
  end
end
