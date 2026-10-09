# frozen_string_literal: true

require_relative 'ex_shared_examples'

describe Skyfall::JetstreamV2::Message do
  include_context "jetstream v2 message"

  let(:data) do
    {
      '$type' => 'network.bsky.jetstream.subscribeEvents#identity',
      'did' => 'did:plc:foobar',
      'seq' => 3333,
      'time' => '2023-11-14T22:16:40Z',
      'identity' => {}
    }
  end

  context 'with invalid data' do
    it 'should throw an error if JSON is not an object' do
      [[], ['identity'], 'identity', 42, true, false, nil].each do |value|
        expect { build_message(JSON.generate(value)) }.to raise_error(Skyfall::DecodeError, 'Expected a JSON object')
      end
    end

    it 'should throw an error if the data is not valid JSON' do
      ['', '{', '{"payload":', 'not JSON'].each do |value|
        expect { build_message(value) }.to raise_error(Skyfall::DecodeError, /Invalid JSON message:/)
      end
    end

    it 'should throw an error if the frame type is not message or error' do
      [nil, 'info', 'identity', 42, [], {}].each do |value|
        json = JSON.generate('$type' => value, 'payload' => data)

        expect { build_message(json) }.to raise_error(
          Skyfall::DecodeError, "Unknown Jetstream v2 frame type: #{value.inspect}"
        )
      end

      expect { build_message(JSON.generate('payload' => data)) }.to raise_error(
        Skyfall::DecodeError, /Unknown Jetstream v2 frame type/
      )
    end

    it 'should throw an error if payload is missing or nil' do
      [{ '$type' => 'message' }, { '$type' => 'message', 'payload' => nil }].each do |frame|
        expect { build_message(JSON.generate(frame)) }.to raise_error(Skyfall::DecodeError, 'Missing message payload')
      end
    end

    it 'should throw an error if payload is not a hash' do
      [[], 'identity', 42, true, false].each do |value|
        expect { build_message(encode_message(value)) }.to raise_error(Skyfall::DecodeError, 'Invalid message payload')
      end
    end

    it 'should throw an error if the event type is missing or invalid' do
      bad_types = [
        nil, [], {}, 42, true, false, '', 'identity', '#identity',
       'com.example.subscribeEvents#identity',
       'network.bsky.jetstream.subscribeEvents',
       'network.bsky.jetstream.subscribeEvents#identity#account'
      ]

      bad_types.each do |value|
        json = encode_message(data.merge('$type' => value))
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, /Invalid event type:/)
      end

      no_type = encode_message(data.reject { |k, v| k == '$type' })
      expect { build_message(no_type) }.to raise_error(Skyfall::DecodeError, /Invalid event type:/)
    end

    it 'should raise SubscriptionError for an error frame' do
      json = JSON.generate('$type' => 'error', 'error' => 'InvalidCursor', 'message' => 'Cursor is invalid')

      expect { build_message(json) }.to raise_error { |error|
        error.should be_a(Skyfall::SubscriptionError)
        error.error_type.should == 'InvalidCursor'
        error.error_message.should == 'Cursor is invalid'
      }
    end

    it 'should accept an error frame without a message' do
      json = JSON.generate('$type' => 'error', 'error' => 'InvalidCursor')

      expect { build_message(json) }.to raise_error { |error|
        error.should be_a(Skyfall::SubscriptionError)
        error.error_type.should == 'InvalidCursor'
        error.error_message.should be_nil
      }
    end
  end
end
