# encoding: UTF-8
require "spec_helper"

module CFoundry
  module V2
    describe Route do
      let(:route) { build(:route) }
      subject { route }

      describe "validations" do
        it { should validate_presence_of(:domain) }
        it { should validate_presence_of(:space) }

        # http://tools.ietf.org/html/rfc1035
        it "only allows host names according to RFC1035" do
          message = "can only include a-z, 0-9 and -"

          route.should allow_value("a", "starts-with-letter", "includes-9-digits", "ends-with-letter",
            "ends-with-digit-9", "can--have--consecutive---dashes", "allows-UPPERCASE-chars").for(:host)

          ["-must-start-with-letter", "9must-start-with-letter", "must-not-end-with-dash-", "must-not-include-punctuation-chars-@\#$%^&*()",
            "must-not-include-special-chars-ä", "must.not.include.dots"].each do |bad_value|
            route.should_not allow_value(bad_value).for(:host).with_message(message)
          end

          route.should ensure_length_of(:host).is_at_most(63)
        end
      end

      describe "errors" do
        before do
          stub(route).create! { raise CFoundry::RouteHostTaken.new("the host is taken", 210003) }
        end

        it "populates errors on host" do
          route.create
          route.errors[:host].first.should =~ /the host is taken/i
        end
      end
    end
  end
end
