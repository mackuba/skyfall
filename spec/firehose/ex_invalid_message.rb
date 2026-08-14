shared_examples_for "invalid firehose message" do
  context 'with invalid data' do
    it 'should raise an error if there are less than 2 cbor objects' do
      data.pop

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Malformed message/)
    end

    it 'should raise an error if there are more than 2 cbor objects' do
      data << { 'op' => 1, 't' => '#delete' }

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Invalid number of objects/)
    end

    it "should raise an error if type object isn't a hash" do
      data[0] = '#account'

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Invalid object type/)
    end

    it "should raise an error if data object isn't a hash" do
      data[1] = ['text', 'Hello world']

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Invalid object type/)
    end

    it "should raise an error if type object's t is missing" do
      data[0].delete('t')

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Missing data/)
    end

    it "should raise an error if type object's t is nil" do
      data[0]['t'] = nil

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Missing data/)
    end

    it "should raise an error if type object's t is not a string" do
      data[0]['t'] = 7

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Invalid object type/)
    end

    it "should raise an error if type object's t doesn't start with a #" do
      data[0]['t'] = 'identity'

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Invalid message type/)
    end

    it "should raise an error if type object's op is missing" do
      data[0].delete('op')

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Missing data/)
    end

    it "should raise an error if type object's op is nil" do
      data[0]['op'] = nil

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Missing data/)
    end

    it "should raise an error if type object's op is not an integer" do
      data[0]['op'] = 'x'

      expect { build_message(cbor) }.to raise_error(Skyfall::DecodeError, /Invalid object type/)
    end

    it "should raise an error if type object's op is not equal 1" do
      data[0]['op'] = 2

      expect { build_message(cbor) }.to raise_error(Skyfall::UnsupportedError, /Unsupported version/)
    end
  end
end
