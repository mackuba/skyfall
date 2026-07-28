# frozen_string_literal: true

require 'cbor'

describe Skyfall::Firehose::Message do
  def encode_message(type, data)
    CBOR.encode(type) + CBOR.encode(data)
  end

  it "should parse commit messages" do
    type = { "op" => 1, "t" => "#commit" }
    data = {
      "seq" => 1,
      "repo" => "did:example:repo",
      "commit" => CBOR::Tagged.new(42, "\x00" + ("a" * 32)),
      "blocks" => "car",
      "ops" => [],
      "time" => "2024-01-01T00:00:00Z"
    }

    message = described_class.new(encode_message(type, data))

    message.should be_a(Skyfall::Firehose::CommitMessage)
    message.type.should eq(:commit)
    message.repo.should eq("did:example:repo")
    message.seq.should eq(1)
  end

  it "should parse account messages" do
    type = { "op" => 1, "t" => "#account" }
    data = {
      "seq" => 2,
      "did" => "did:example:acct",
      "time" => "2024-01-01T00:00:00Z",
      "active" => true
    }

    message = described_class.new(encode_message(type, data))

    message.should be_a(Skyfall::Firehose::AccountMessage)
    message.active?.should be(true)
  end

  it "should parse info messages" do
    type = { "op" => 1, "t" => "#info" }
    data = { "name" => "OutdatedCursor", "message" => "Old" }

    message = described_class.new(encode_message(type, data))

    message.should be_a(Skyfall::Firehose::InfoMessage)
    message.to_s.should include("OutdatedCursor")
  end

  it "should treat unknown messages as unknown" do
    type = { "op" => 1, "t" => "#mystery" }
    data = { "seq" => 3 }

    message = described_class.new(encode_message(type, data))

    message.should be_a(Skyfall::Firehose::UnknownMessage)
    message.unknown?.should be(true)
  end

  it "should raise when error is present" do
    type = { "op" => 1, "t" => "#commit" }
    data = { "error" => "Boom", "message" => "Bad" }

    expect { described_class.new(encode_message(type, data)) }.to raise_error(Skyfall::SubscriptionError)
  end

  it "should raise on invalid message format" do
    expect { described_class.new(CBOR.encode({})) }.to raise_error(Skyfall::DecodeError)
  end
end
