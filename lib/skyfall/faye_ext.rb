require 'websocket/driver'
require_relative 'firehose'

module WebSocket
  class Driver
    class Hybi
      def emit_message
        message  = @extensions.process_incoming_message(@message)
        @message = nil

        payload = message.data

        case message.opcode
          when OPCODES[:text] then
            payload = Driver.encode(payload, Encoding::UTF_8)
            payload = nil unless payload.valid_encoding?
          # when OPCODES[:binary]
          #   payload = payload.bytes.to_a
        end

        if payload
          emit(:message, MessageEvent.new(payload))
        else
          fail(:encoding_error, 'Could not decode a text frame as UTF-8')
        end
      rescue ::WebSocket::Extensions::ExtensionError => error
        fail(:extension_error, error.message)
      end
    end
  end
end

module Skyfall
  class Firehose
    def handle_message(msg)
      data = msg.data #.pack('C*')
      @handlers[:raw_message]&.call(data)

      if @handlers[:message]
        atp_message = Message.new(data)
        @cursor = atp_message.seq
        @handlers[:message].call(atp_message)
      else
        @cursor = nil
      end
    end
  end
end
