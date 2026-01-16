# frozen_string_literal: true

describe Skyfall::Label do
  it "should parse a valid label" do
    cid = Skyfall::CID.new("b" * 36).to_s
    data = {
      "ver" => 1,
      "src" => "did:example:labeller",
      "uri" => "at://did:example:foo/app.bsky.feed.post/123",
      "cid" => cid,
      "val" => "test",
      "cts" => "2024-01-01T00:00:00Z",
      "exp" => "2025-01-01T00:00:00Z",
      "neg" => true
    }

    label = described_class.new(data)

    label.version.should eq(1)
    label.authority.should eq("did:example:labeller")
    label.subject.should eq("at://did:example:foo/app.bsky.feed.post/123")
    label.cid.should be_a(Skyfall::CID)
    label.value.should eq("test")
    label.negation?.should be(true)
    label.created_at.should be_a(Time)
    label.expires_at.should be_a(Time)
  end

  it "should raise on invalid version" do
    data = { "ver" => 2, "src" => "did:example:labeller", "uri" => "did:example:foo" }

    expect { described_class.new(data) }.to raise_error(Skyfall::UnsupportedError)
  end

  it "should raise when required fields are missing" do
    data = { "ver" => 1 }

    expect { described_class.new(data) }.to raise_error(Skyfall::DecodeError)
  end
end
