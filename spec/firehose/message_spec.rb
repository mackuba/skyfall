# frozen_string_literal: true

describe Skyfall::Firehose::Message do
  let(:type) {{ 'op' => 1, 't' => '#account' }}
  let(:data) {{ 'seq' => 2222, 'did' => 'did:plc:foobar', 'time' => '2023-11-14T22:13:20.000008Z', 'active' => true }}
  let(:message) { described_class.new(cbor_sequence(type, data)) }

  it 'should expose cursor as an alias for seq' do
    message.cursor.should == 2222
    message.cursor.should == message.seq
  end

  it 'should return time in Unix microseconds via #time_us' do
    message.time_us.should == 1_700_000_000_000_008
  end

  it 'should raise SubscriptionError for an error frame' do
    type = { 'op' => -1 }
    data = { 'error' => 'Boom', 'message' => 'Server exploded' }

    expect { described_class.new(cbor_sequence(type, data)) }.to raise_error { |e|
      e.should be_a(Skyfall::SubscriptionError)
      e.error_type.should == 'Boom'
      e.error_message.should == 'Server exploded'
    }
  end
end
