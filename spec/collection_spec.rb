# frozen_string_literal: true

describe Skyfall::Collection do
  it "should map known collection names to short codes" do
    described_class.short_code(described_class::BSKY_POST).should eq(:bsky_post)
  end

  it "should return :unknown for unknown collections" do
    described_class.short_code("app.bsky.unknown").should eq(:unknown)
  end

  it "should map short codes back to collection names" do
    described_class.from_short_code(:bsky_like).should eq(described_class::BSKY_LIKE)
  end

  it "should return nil for unknown short codes" do
    described_class.from_short_code(:nonexistent).should be_nil
  end
end
