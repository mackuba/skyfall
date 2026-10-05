# frozen_string_literal: true

describe Skyfall do
  it "should have a version number" do
    Skyfall::VERSION.should_not be_nil
  end
end
