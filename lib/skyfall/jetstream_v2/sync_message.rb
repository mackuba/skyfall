# frozen_string_literal: true

require_relative 'message'
require 'base64'
require 'oxygene'

module Skyfall

  #
  # Firehose message which declares the current state of the repository. The message is meant to
  # trigger a resynchronization of the repository from a receiving consumer, if the consumer detects
  # from the message rev that it must have missed some events from that repository.
  #
  # The sync message can be emitted by a PDS or relay to force a repair of a broken account state,
  # or e.g. when an account is created, migrated or recovered from a CAR backup.
  #

  class JetstreamV2::SyncMessage < JetstreamV2::Message

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      super

      sync = @payload['sync']

      unless sync.is_a?(Hash) && !sync['rev'].nil? && sync['blocks'].is_a?(Hash) && sync['blocks']['$bytes'].is_a?(String)
        raise DecodeError, "Missing event details (sync)"
      end
    end

    # @return [String] current revision of the repo
    def rev
      @payload['sync']['rev']
    end

    # @return [Oxygene::CARArchive] commit data in the form of a parsed CAR archive
    #
    # @raise [Oxygene::DecodeError] if the archive header has missing or invalid fields
    # @raise [Oxygene::UnsupportedError] if the archive uses an unsupported CAR version
    # @raise [DecodeError] if the blocks data is not encoded with valid Base64
    #
    def blocks
      return @blocks if @blocks

      encoded_bytes = @payload['sync']['blocks']['$bytes']
      padded_bytes = encoded_bytes + '=' * ((4 - encoded_bytes.length % 4) % 4)

      @blocks = Oxygene::CARArchive.new(Base64.strict_decode64(padded_bytes))
    rescue ArgumentError => e
      raise DecodeError, "Invalid sync blocks: #{e.message}"
    end
  end
end
