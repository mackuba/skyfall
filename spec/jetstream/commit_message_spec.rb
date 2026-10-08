# frozen_string_literal: true

require 'json'
require_relative 'ex_invalid_message'

describe Skyfall::Jetstream::CommitMessage do
  let(:json) { JSON.generate(data) }

  def build_message(json)
    Skyfall::Jetstream::Message.new(json)
  end

  let(:data) do
    {
      'kind' => 'commit',
      'did' => 'did:plc:qwerty',
      'time_us' => 1_700_000_005_000_000,
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

  include_examples "invalid jetstream message"

  context 'with missing data' do
    it "should throw an error if commit is not a hash" do
      [[], 'commit', 42, true, false].each do |value|
        json = JSON.generate(data.merge('commit' => value))
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Invalid commit object')
      end
    end

    it 'should throw an error if commit is missing' do
      data.delete('commit')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing commit object')
    end

    it 'should throw an error if commit is nil' do
      data['commit'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing commit object')
    end

    %w(collection rkey operation rev).each do |field|
      it "should throw an error if commit.#{field} is missing" do
        data['commit'].delete(field)

        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (commit.#{field})")
      end

      it "should throw an error if commit.#{field} is nil" do
        data['commit'][field] = nil

        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (commit.#{field})")
      end
    end
  end

  context 'with valid data' do
    it 'should parse a commit message' do
      message = build_message(json)
      message.should be_a(Skyfall::Jetstream::CommitMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :commit
      message.kind.should == :commit

      message.repo.should == 'did:plc:qwerty'
      message.did.should == 'did:plc:qwerty'

      message.seq.should == 1_700_000_005_000_000
      message.cursor.should == 1_700_000_005_000_000
      message.time_us.should == 1_700_000_005_000_000

      message.rev.should == '3mx3e5ky4x32n'
      message.should_not be_unknown
    end

    context 'if an explicit cursor field is included' do
      it 'should use the explicit cursor for seq and cursor' do
        data['cursor'] = 17
        message = build_message(json)

        message.seq.should == 17
        message.cursor.should == 17
      end      

      it 'should still return a timestamp from time_us' do
        message = build_message(json)
        message.time_us.should == 1_700_000_005_000_000
      end

      it "should not use the cursor if it's nil" do
        data['cursor'] = nil
        message = build_message(json)

        message.seq.should == 1_700_000_005_000_000
        message.cursor.should == 1_700_000_005_000_000
        message.time_us.should == 1_700_000_005_000_000
      end      
    end

    it 'should have a time method that returns the timestamp as Time' do
      message = build_message(json)
      message.time.should == Time.parse('2023-11-14T22:13:25Z')
    end

    it 'should work when created using the CommitMessage constructor' do
      message = Skyfall::Jetstream::CommitMessage.new(json)
      message.should be_a(Skyfall::Jetstream::CommitMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Jetstream::IdentityMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, /Expected 'identity' message, got 'commit'/)
    end

    describe '#operation' do
      it 'should return an Operation' do
        message = build_message(json)
        message.operation.should be_a(Skyfall::Jetstream::Operation)
        message.op.should equal(message.operation)
      end

      it 'should expose the operation details' do
        op = build_message(json).operation

        op.repo.should == 'did:plc:qwerty'
        op.collection.should == 'app.bsky.feed.post'
        op.rkey.should == '3mt37ifa2ev2f'
        op.action.should == :create
        op.raw_record['text'].should == 'Hello world'
      end
    end

    describe '#operations' do
      it 'should return an array with the single operation' do
        message = build_message(json)

        message.operations.length.should == 1
        message.operations[0].should equal(message.operation)
        message.ops.should == message.operations
      end
    end

    context 'with a delete operation' do
      before do
        data['commit'].update('operation' => 'delete')
        data['commit'].delete('cid')
        data['commit'].delete('record')
      end

      it 'should return a delete operation without cid or record' do
        op = build_message(json).operation

        op.action.should == :delete
        op.cid.should be_nil
        op.raw_record.should be_nil
      end
    end
  end
end
