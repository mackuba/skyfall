# frozen_string_literal: true

describe Skyfall::ReactorActiveError do
  it "should include a helpful message" do
    error = described_class.new

    error.message.should include("EventMachine reactor thread")
  end
end

describe Skyfall::SubscriptionError do
  it "should expose error details" do
    error = described_class.new("Boom", "Something happened")

    error.error_type.should eq("Boom")
    error.error_message.should eq("Something happened")
    error.message.should include("Boom")
  end
end
