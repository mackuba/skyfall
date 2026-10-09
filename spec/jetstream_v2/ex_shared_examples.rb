# frozen_string_literal: true

require 'json'

shared_context "jetstream v2 message" do
  let(:json) { encode_message(data) }

  def encode_message(payload)
    JSON.generate('$type' => 'message', 'payload' => payload)
  end

  def build_message(json)
    Skyfall::JetstreamV2::Message.new(json)
  end
end

shared_examples_for "invalid jetstream v2 message" do
  context 'with invalid data' do
    %w(did seq time).each do |field|
      it "should throw an error if #{field} is missing" do
        data.delete(field)
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (#{field})")
      end

      it "should throw an error if #{field} is nil" do
        data[field] = nil
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, "Missing event details (#{field})")
      end
    end

    it 'should throw an error if seq is not an integer' do
      ['42', 42.5, [], {}, true, false].each do |value|
        json = encode_message(data.merge('seq' => value))
        expect { build_message(json) }.to raise_error(Skyfall::DecodeError, 'Invalid event sequence number')
      end
    end
  end
end

shared_examples_for "jetstream v2 timestamps" do |timestamp, microseconds|
  it 'should have a time method that returns the timestamp as Time' do
    message = build_message(json)
    message.time.should == Time.iso8601(timestamp)
  end

  it 'should have a time_us method that returns the timestamp in microseconds' do
    message = build_message(json)
    message.time_us.should == microseconds
  end

  it 'should parse witnessedAt independently of time' do
    data['witnessedAt'] = '2023-11-14T22:13:20.000009Z'

    message = build_message(json)
    message.witnessed_at.should == Time.utc(2023, 11, 14, 22, 13, 20, 9)
    message.time.should == Time.iso8601(timestamp)
  end

  it 'should return nil from witnessed_at if witnessedAt is missing or nil' do
    payload = data.reject { |k, v| k == 'witnessedAt' }
    message = build_message(encode_message(payload))
    message.witnessed_at.should be_nil

    payload = data.merge('witnessedAt' => nil)
    message = build_message(encode_message(payload))
    message.witnessed_at.should be_nil
  end
end
