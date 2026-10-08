# frozen_string_literal: true

require 'json'

describe Skyfall::Jetstream::Operation do
  let(:commit_data) do
    {
      'kind' => 'commit',
      'did' => 'did:plc:qwerty',
      'time_us' => 1_700_000_003_456_789,
      'commit' => {
        'rev' => '3mx3e5ky4x32n',
        'collection' => 'app.bsky.feed.post',
        'rkey' => '3mt37ifa2ev2f',
        'cid' => 'bafyreibcmaq3rvoyt3a7xzl6sgthpnv3do4wgrpc47zmhpzvl6bogi57ra',
        'operation' => 'create',
        'record' => {
          'text' => 'Hello world',
          'createdAt' => '2023-11-14T22:13:19.000Z'
        }
      }
    }
  end

  let(:message) { Skyfall::Jetstream::Message.new(JSON.generate(commit_data)) }
  let(:operation) { Skyfall::Jetstream::Operation.new(message, commit_data['commit']) }

  it 'should read repo information from the CommitMessage' do
    operation.repo.should == message.repo
    operation.did.should == message.repo
  end

  it 'should parse the operation details' do
    operation.collection.should == 'app.bsky.feed.post'
    operation.rkey.should == '3mt37ifa2ev2f'
    operation.path.should == 'app.bsky.feed.post/3mt37ifa2ev2f'
    operation.uri.should == 'at://did:plc:qwerty/app.bsky.feed.post/3mt37ifa2ev2f'
    operation.action.should == :create
  end

  describe '#type' do
    it 'should return a symbolic shortcode of the record collection' do
      operation.type.should == :bsky_post
    end

    context 'with an unrecognized collection' do
      before do
        commit_data['commit']['collection'] = 'com.example.thing'
      end

      it 'should return :unknown' do
        operation.type.should == :unknown
      end
    end
  end

  describe '#cid' do
    it 'should return a parsed CID' do
      operation.cid.should be_a(Oxygene::CID)
      operation.cid.to_s.should == 'bafyreibcmaq3rvoyt3a7xzl6sgthpnv3do4wgrpc47zmhpzvl6bogi57ra'
    end

    context "if the operation doesn't have a cid" do
      before do
        commit_data['commit'].delete('cid')
      end

      it 'should return nil' do
        operation.cid.should be_nil
      end
    end

    context "if the operation's cid is nil" do
      before do
        commit_data['commit']['cid'] = nil
      end

      it 'should return nil' do
        operation.cid.should be_nil
      end
    end
  end

  describe '#raw_record' do
    it 'should return the record data as a plain Hash' do
      operation.raw_record.should be_a(Hash)
      operation.raw_record['text'].should == 'Hello world'
    end

    context "if the operation doesn't have a record" do
      before do
        commit_data['commit'].update('operation' => 'delete')
        commit_data['commit'].delete('record')
      end

      it 'should return nil' do
        operation.raw_record.should be_nil
      end
    end
  end

  describe '#inspect' do
    it 'should not include the message object' do
      operation.inspect.should_not include('@message')
      operation.inspect.should include('@json')
    end
  end
end
