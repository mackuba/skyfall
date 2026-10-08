# frozen_string_literal: true

require 'json'
require_relative 'ex_invalid_message'

describe Skyfall::Jetstream::AccountMessage do
  let(:json) { JSON.generate(data) }

  def build_message(json)
    Skyfall::Jetstream::Message.new(json)
  end

  let(:data) do
    {
      'kind' => 'account',
      'did' => 'did:plc:foobar',
      'time_us' => 1_700_000_100_000_000,
      'account' => { 'active' => true }
    }
  end

  include_examples "invalid jetstream message"

  context 'with missing data' do
    it "should throw an error if account is not a hash" do
      [[], 'account', 42, true, false].each do |value|
        json = JSON.generate(data.merge('account' => value))
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Invalid account object')
      end
    end

    it 'should throw an error if account is missing' do
      data.delete('account')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing account object')
    end

    it 'should throw an error if account is nil' do
      data['account'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing account object')
    end

    it 'should throw an error if account.active is missing' do
      data['account'].delete('active')

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing event details (account.active)')
    end

    it 'should throw an error if account.active is nil' do
      data['account']['active'] = nil

      expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Missing event details (account.active)')
    end
  end

  context 'with valid data' do
    it 'should parse an account message' do
      message = build_message(json)
      message.should be_a(Skyfall::Jetstream::AccountMessage)
      message.json.should == JSON.parse(json)

      message.type.should == :account
      message.kind.should == :account

      message.repo.should == 'did:plc:foobar'
      message.did.should == 'did:plc:foobar'

      message.seq.should == 1_700_000_100_000_000
      message.cursor.should == 1_700_000_100_000_000
      message.time_us.should == 1_700_000_100_000_000

      message.should_not be_unknown
    end

    context 'if an explicit cursor field is included' do
      it 'should use the explicit cursor for seq and cursor' do
        data['cursor'] = 42
        message = build_message(json)

        message.seq.should == 42
        message.cursor.should == 42
      end      

      it 'should still return a timestamp from time_us' do
        message = build_message(json)
        message.time_us.should == 1_700_000_100_000_000
      end

      it "should not use the cursor if it's nil" do
        data['cursor'] = nil
        message = build_message(json)

        message.seq.should == 1_700_000_100_000_000
        message.cursor.should == 1_700_000_100_000_000
        message.time_us.should == 1_700_000_100_000_000
      end      
    end

    it 'should have a time method that returns the timestamp as Time' do
      message = build_message(json)
      message.time.should == Time.parse('2023-11-14T22:15:00Z')
    end

    it 'should work when created using the AccountMessage constructor' do
      message = Skyfall::Jetstream::AccountMessage.new(json)
      message.should be_a(Skyfall::Jetstream::AccountMessage)
    end

    it "should throw an error when created using a different message's constructor" do
      expect { Skyfall::Jetstream::CommitMessage.new(json) }
        .to raise_error(Skyfall::DecodeError, /Expected 'commit' message, got 'account'/)
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

    context 'for an active account' do
      it "should say it's active" do
        message = build_message(json)
        message.active?.should == true
      end

      it 'should have a nil status' do
        message = build_message(json)
        message.status.should be_nil
      end

      context 'with a status value present' do
        before do
          data['account']['status'] = 'takendown'
        end

        it 'should return the status as a symbol' do
          message = build_message(json)
          message.status.should == :takendown
        end
      end
    end

    context 'for an inactive account' do
      before do
        data['account'].update('active' => false, 'status' => 'takendown')
      end

      it "should say it's not active" do
        message = build_message(json)
        message.active?.should == false
      end

      it 'should have a status set' do
        message = build_message(json)
        message.status.should == :takendown
      end
    end
  end
end
