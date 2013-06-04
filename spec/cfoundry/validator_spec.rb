require "spec_helper"

module CFoundry
  describe Validator do
    let(:validator) { described_class }

    describe "value_matches?" do
      it "returns true on nil values" do
        validator.value_matches?(nil, :something).should be_true
      end

      context "with a type of Class" do
        it "returns true when value is of type class" do
          validator.value_matches?(1, Integer).should be_true
        end
      end

      context "with a Regex" do
        it "returns true when the regex matches" do
          validator.value_matches?("value", /lue/).should == true
        end
      end

      context "with type of url" do
        it "requires http or https urls" do
          validator.value_matches?("http:whatever", :url).should be_true
          validator.value_matches?("https:whatever", :url).should be_true
          validator.value_matches?("htt_no:whatever", :url).should be_false
        end
      end

      context "with type of https_url" do
        it "requires http or https urls" do
          validator.value_matches?("https:whatever", :https_url).should be_true
          validator.value_matches?("http:whatever", :https_url).should be_false
        end
      end

      context "with type boolean" do
        it "returns true on presence of true or false" do
          validator.value_matches?(true, :boolean).should be_true
          validator.value_matches?(false, :boolean).should be_true
          validator.value_matches?("no boolean", :boolean).should be_false
        end
      end

      context "with an Array" do
        it "returns true when all elements are of same type" do
          validator.value_matches?(["https:whatever"], [String]).should be_true
          validator.value_matches?(["https:whatever"], [Integer]).should be_false
        end
      end

      context "with a hash" do
        it "returns true when specified types match" do
          validator.value_matches?({:name => "thing"}, {:name => String}).should be_true
          validator.value_matches?({:name => "thing", :unspecified => 1}, {:name => String}).should be_true
          validator.value_matches?({:name => 1}, {:name => String}).should be_false
        end
      end

      it "returns true when type is nil" do
        validator.value_matches?("some value", nil).should be_true
      end

      context "with a symbol" do
        it "returns true when the value is of specified type" do
          validator.value_matches?("some value", :string).should be_true
          validator.value_matches?("some value", :integer).should be_false
        end
      end
    end

    describe "validate_type" do
      it "passes validation with a nil value" do
        expect {
          validator.validate_type(nil, :whatever)
        }.to_not raise_error
      end

      it "passes validation when the value matches" do
        expect {
          validator.validate_type("string", :string)
        }.to_not raise_error
      end

      it "raises a validation error when value does not match" do
        expect {
          validator.validate_type("string", :integer)
        }.to raise_error(CFoundry::Mismatch)
      end
    end
  end
end