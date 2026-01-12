# frozen_string_literal: true

require 'json'

describe Skyfall::Jetstream::Message do
  it "should parse commit messages" do
    json = {
      "kind" => "commit",
      "did" => "did:example:repo",
      "time_us" => 123,
      "commit" => {
        "collection" => "app.bsky.feed.post",
        "rkey" => "key",
        "operation" => "create",
        "record" => { "text" => "Hello" }
      }
    }

    message = described_class.new(JSON.dump(json))

    message.should be_a(Skyfall::Jetstream::CommitMessage)
    message.type.should eq(:commit)
    message.operation.action.should eq(:create)
  end

  it "should parse identity messages" do
    json = {
      "kind" => "identity",
      "did" => "did:example:repo",
      "time_us" => 123,
      "identity" => { "handle" => "alice.test" }
    }

    message = described_class.new(JSON.dump(json))

    message.should be_a(Skyfall::Jetstream::IdentityMessage)
    message.handle.should eq("alice.test")
  end

  it "should parse unknown message types" do
    json = { "kind" => "mystery", "did" => "did:example:repo", "time_us" => 123 }

    message = described_class.new(JSON.dump(json))

    message.should be_a(Skyfall::Jetstream::UnknownMessage)
    message.unknown?.should be(true)
  end

  it "should raise when required fields are missing" do
    json = { "kind" => "commit" }

    expect { described_class.new(JSON.dump(json)) }.to raise_error(Skyfall::DecodeError)
  end
end
