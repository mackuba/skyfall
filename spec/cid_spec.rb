# frozen_string_literal: true

describe Skyfall::CID do
  it "should build from a CBOR tag" do
    data = "\x00" + ("a" * 32)
    tag = Struct.new(:value).new(data)

    cid = described_class.from_cbor_tag(tag)

    cid.data.should eq("a" * 32)
  end

  it "should raise when CBOR tag is invalid" do
    tag = Struct.new(:value).new("\x01bad")

    expect { described_class.from_cbor_tag(tag) }.to raise_error(Skyfall::DecodeError)
  end

  it "should build from JSON string" do
    cid = described_class.new("b" * 36)

    parsed = described_class.from_json(cid.to_s)

    parsed.should eq(cid)
  end

  it "should raise when JSON CID has unexpected length" do
    expect { described_class.from_json("bshort") }.to raise_error(Skyfall::DecodeError)
  end

  it "should raise when JSON CID has invalid prefix" do
    expect { described_class.from_json("z" + ("a" * 58)) }.to raise_error(Skyfall::DecodeError)
  end

  it "should return a multibase string" do
    cid = described_class.new("b" * 36)

    cid.to_s.should start_with("b")
  end

  it "should inspect with CID wrapper" do
    cid = described_class.new("b" * 36)

    cid.inspect.should include("CID(\"")
  end
end
