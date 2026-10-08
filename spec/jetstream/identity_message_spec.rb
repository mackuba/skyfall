# frozen_string_literal: true

require 'json'
require_relative 'ex_invalid_message'

describe Skyfall::Jetstream::IdentityMessage do
  let(:json) { JSON.generate(data) }

  def build_message(json)
    Skyfall::Jetstream::Message.new(json)
  end

  let(:data) do
    {
      'kind' => 'identity',
      'did' => 'did:plc:foobar',
      'time_us' => 1_700_000_200_000_000,
      'identity' => { 'handle' => 'alice.test' }
    }
  end

  include_examples "invalid jetstream message"

  context 'with missing data' do
    it "should throw an error if identity is not a hash" do
      [[], 'identity', 42, true, false].each do |value|
        json = JSON.generate(data.merge('identity' => value))
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Invalid identity object')
      end
    end

    it 'should throw an error if identity is missing' do
      data.delete('identity')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing identity object')
    end

    it 'should throw an error if identity is nil' do
      data['identity'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing identity object')
    end
  end

  context 'with valid data' do
    it 'should parse an identity message' do
      message = build_message(json)
      message.should be_a(Skyfall::Jetstream::IdentityMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :identity
      message.kind.should == :identity

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 1_700_000_200_000_000
      message.cursor.should == 1_700_000_200_000_000
      message.time_us.should == 1_700_000_200_000_000

      message.should_not be_unknown
    end

    context 'if an explicit cursor field is included' do
      it 'should use the explicit cursor for seq and cursor' do
        data['cursor'] = 66
        message = build_message(json)

        message.seq.should == 66
        message.cursor.should == 66
      end      

      it 'should still return a timestamp from time_us' do
        message = build_message(json)
        message.time_us.should == 1_700_000_200_000_000
      end

      it "should not use the cursor if it's nil" do
        data['cursor'] = nil
        message = build_message(json)

        message.seq.should == 1_700_000_200_000_000
        message.cursor.should == 1_700_000_200_000_000
        message.time_us.should == 1_700_000_200_000_000
      end      
    end

    it 'should have a time method that returns the timestamp as Time' do
      message = build_message(json)
      message.time.should == Time.parse('2023-11-14T22:16:40Z')
    end

    it 'should work when created using the IdentityMessage constructor' do
      message = Skyfall::Jetstream::IdentityMessage.new(json)
      message.should be_a(Skyfall::Jetstream::IdentityMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Jetstream::AccountMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, /Expected 'account' message, got 'identity'/)
    end

    it 'should have an operations field that returns []' do
      message = build_message(json)
      message.operations.should == []
      message.ops.should == []
    end

    it 'should have an operation field that returns nil' do
      message = build_message(json)
      message.operation.should be_nil
      message.op.should be_nil
    end

    describe '#handle' do
      context 'with a handle present' do
        it 'should return the handle' do
          message = build_message(json)
          message.handle.should == 'alice.test'
        end
      end

      context 'with no handle' do
        before do
          data['identity'].delete('handle')
        end

        it 'should return nil' do
          message = build_message(json)
          message.handle.should be_nil
        end
      end
    end
  end
end
