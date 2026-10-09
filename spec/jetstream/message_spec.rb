# frozen_string_literal: true

require 'json'

describe Skyfall::Jetstream::Message do
  context 'with invalid data' do
    it 'should raise an error if the data is not valid JSON' do
      expect { Skyfall::Jetstream::Message.new('invalid json') }.to raise_error(
        Skyfall::DecodeError, /Invalid JSON message:/
      )
    end

    it 'should raise an error if the parsed JSON is not a Hash' do
      expect { Skyfall::Jetstream::Message.new('[]') }.to raise_error(
        Skyfall::DecodeError, /Expected a JSON object/
      )
    end
  end
end
