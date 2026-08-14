describe Skyfall::Firehose::Message do
  it 'should raise SubscriptionError when error is present' do
    type = { 'op' => 1, 't' => '#commit' }
    data = { 'error' => 'Boom', 'message' => 'Server exploded' }

    expect { described_class.new(cbor_sequence(type, data)) }.to raise_error { |e|
      e.should be_a(Skyfall::SubscriptionError)
      e.error_type.should == 'Boom'
      e.error_message.should == 'Server exploded'
    }
  end
end
