# frozen_string_literal: true

require 'stringio'

describe Skyfall::Firehose::Operation do
  it "should expose repo information" do
    message = Struct.new(:repo, :raw_record_for_operation).new("did:example:repo", nil)
    json = { "path" => "app.bsky.feed.post/123", "action" => "create" }

    op = described_class.new(message, json)

    op.repo.should eq("did:example:repo")
    op.did.should eq("did:example:repo")
  end

  it "should parse path details" do
    message = Struct.new(:repo, :raw_record_for_operation).new("did:example:repo", nil)
    json = { "path" => "app.bsky.feed.post/123", "action" => "update" }

    op = described_class.new(message, json)

    op.collection.should eq("app.bsky.feed.post")
    op.rkey.should eq("123")
    op.uri.should eq("at://did:example:repo/app.bsky.feed.post/123")
    op.action.should eq(:update)
    op.type.should eq(:bsky_post)
  end

  it "should warn once when path is called" do
    message = Struct.new(:repo, :raw_record_for_operation).new("did:example:repo", nil)
    json = { "path" => "app.bsky.feed.post/123", "action" => "delete" }

    described_class.class_variable_set(:@@path_warning_printed, false)

    op = described_class.new(message, json)

    stderr = StringIO.new
    original_stderr = $stderr
    $stderr = stderr

    op.path.should eq("app.bsky.feed.post/123")
    op.path.should eq("app.bsky.feed.post/123")

    stderr.string.should include("deprecated")
  ensure
    $stderr = original_stderr
  end
end

describe Skyfall::Jetstream::Operation do
  it "should expose repo information" do
    message = Struct.new(:repo).new("did:example:repo")
    json = { "collection" => "app.bsky.feed.post", "rkey" => "123", "operation" => "create" }

    op = described_class.new(message, json)

    op.repo.should eq("did:example:repo")
    op.did.should eq("did:example:repo")
  end

  it "should build record details" do
    message = Struct.new(:repo).new("did:example:repo")
    json = {
      "collection" => "app.bsky.feed.post",
      "rkey" => "123",
      "operation" => "create",
      "record" => { "text" => "Hi" }
    }

    op = described_class.new(message, json)

    op.collection.should eq("app.bsky.feed.post")
    op.rkey.should eq("123")
    op.uri.should eq("at://did:example:repo/app.bsky.feed.post/123")
    op.action.should eq(:create)
    op.raw_record.should eq({ "text" => "Hi" })
    op.type.should eq(:bsky_post)
  end

  it "should warn once when path is called" do
    message = Struct.new(:repo).new("did:example:repo")
    json = { "collection" => "app.bsky.feed.post", "rkey" => "123", "operation" => "delete" }

    described_class.class_variable_set(:@@path_warning_printed, false)

    op = described_class.new(message, json)

    stderr = StringIO.new
    original_stderr = $stderr
    $stderr = stderr

    op.path.should eq("app.bsky.feed.post/123")
    op.path.should eq("app.bsky.feed.post/123")

    stderr.string.should include("deprecated")
  ensure
    $stderr = original_stderr
  end
end
