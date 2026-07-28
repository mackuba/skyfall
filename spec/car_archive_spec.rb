# frozen_string_literal: true

require 'base64'
require 'cbor'

describe Skyfall::CarArchive do
  it "should convert nested CBOR tagged values to CID links" do
    tag = CBOR::Tagged.new(42, "\x00" + ("a" * 32))
    data = { "link" => tag }

    described_class.convert_data(data)

    data["link"]["$link"].should be_a(Skyfall::CID)
  end

  it "should convert binary strings to bytes objects" do
    bytes = "\x00\x01".b
    data = { "payload" => bytes }

    described_class.convert_data(data)

    data["payload"]["$bytes"].should eq(Base64.encode64(bytes).chomp.gsub(/=+$/, ""))
  end

  it "should raise when converting unexpected value types" do
    expect { described_class.convert_data("bad") }.to raise_error(Skyfall::DecodeError)
  end
end
