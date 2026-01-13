# frozen_string_literal: true

require 'cbor'
require 'stringio'

module Skyfall

  # @private
  module Extensions

    refine StringIO do
      # https://en.wikipedia.org/wiki/LEB128
      def read_varint
        shift = 1
        value = 0

        loop do
          byte = self.readbyte
          value += byte % 128 * shift
          break if byte < 128
          shift *= 128
        end

        value
      end
    end

    refine CBOR.singleton_class do
      def decode_sequence(data)
        unpacker = CBOR::Unpacker.new(StringIO.new(data))
        unpacker.each.to_a
      end
    end

  end
end
