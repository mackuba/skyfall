# frozen_string_literal: true

require 'stringio'

describe Skyfall::Firehose::Operation do
  let(:commit_data) {[
    { 'op' => 1, 't' => '#commit' },
    {
      'seq' => 1024,
      'repo' => 'did:plc:qwerty',
      'commit' => CBOR::Tagged.new(
        42, "\x00\x01q\x12 \t\xCF\xF0vKM\f \xE0$5\xA9\xED\xB5\x8B5T\xC4aH\x87\x88\xDF\x80_\xCCx\x86Z\xBB\xAE\x91".b
      ),
      'rev' => '3me4sottxa22d',
      'blocks' => blocks,
      'ops' => [{
        'cid' => CBOR::Tagged.new(
          42, "\x00\x01q\x12 g_\xBA\xB0\x93\xDE\xDBN\xEB\xD9WT\xEF\xA6l\xD3p%\xCB\x8F\xD2\x8E\x1E*\xE6xA|\xC8\x1EJ6".b
        ),
        'path' => "app.bsky.feed.post/3mt37ifa2ev2f",
        'action' => 'create'
      }],
      'time' => '2024-06-24T01:59:05.668Z'
    }
  ]}

  let(:blocks) { File.binread(File.expand_path("../fixtures/attie.car", __dir__)) }
  let(:commit) { Skyfall::Firehose::Message.new(cbor_sequence(*commit_data)) }

  it "should read repo information from the CommitMessage" do
    op = described_class.new(commit, commit_data[1]['ops'][0])

    op.repo.should == commit.repo
    op.did.should == commit.repo
  end

  it "should parse operation details" do
    op = described_class.new(commit, commit_data[1]['ops'][0])

    op.collection.should == "app.bsky.feed.post"
    op.rkey.should == "3mt37ifa2ev2f"
    op.path.should == "app.bsky.feed.post/3mt37ifa2ev2f"
    op.uri.should == "at://did:plc:qwerty/app.bsky.feed.post/3mt37ifa2ev2f"
    op.path.should == "app.bsky.feed.post/3mt37ifa2ev2f"
    op.action.should == :create

    op.cid.should be_a(Oxygene::CID)
    op.cid.to_s.should == 'bafyreidhl65lbe663nhoxwkxktx2m3gtoas4xd6srypcvztyif6mqhskgy'
  end

  describe '#type' do
    it 'should return a symbolic shortcode of the record collection' do
      op = described_class.new(commit, commit_data[1]['ops'][0])
      op.type.should == :bsky_post
    end
  end

  describe '#raw_record' do
    it 'should look up the record data through the CommitMessage' do
      op = described_class.new(commit, commit_data[1]['ops'][0])
      record = op.raw_record

      record.should be_a(Hash)
      record['text'].should start_with('New Attie feature, thanks for feedback from users:')      
    end
  end

  context "if operation doesn't have a cid" do
    it 'should return nil from #cid' do
      commit_data[1]['ops'][0]['cid'] = nil

      op = described_class.new(commit, commit_data[1]['ops'][0])
      op.cid.should be_nil
    end
  end
end
