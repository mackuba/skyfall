# frozen_string_literal: true

require_relative '../car_archive'
require_relative '../firehose'
require_relative 'message'

module Skyfall

  #
  # Firehose message which declares the current state of the repository. The message is meant to
  # trigger a resynchronization of the repository from a receiving consumer, if the consumer detects
  # from the message rev that it must have missed some events from that repository.
  #
  # The sync message can be emitted by a PDS or relay to force a repair of a broken account state,
  # or e.g. when an account is created, migrated or recovered from a CAR backup.
  #

  class Firehose::SyncMessage < Firehose::Message

    #
    # @private
    # @param type_object [Hash] first decoded CBOR frame with metadata
    # @param data_object [Hash] second decoded CBOR frame with payload
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(type_object, data_object)
      super
      check_if_not_nil 'seq', 'did', 'blocks', 'rev', 'time'
    end

    def rev
      @rev ||= @data_object['rev']
    end

    # @return [Skyfall::CarArchive] commit data in the form of a parsed CAR archive
    def blocks
      @blocks ||= CarArchive.new(@data_object['blocks'])
    end
  end
end
