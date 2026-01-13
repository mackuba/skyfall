# frozen_string_literal: true

require_relative '../firehose'
require_relative 'message'

module Skyfall

  #
  # An informational firehose message from the websocket service itself, unrelated to any repos.
  #
  # Currently there is only one type of message defined, `"OutdatedCursor"`, which is sent when
  # the client connects with a cursor that is older than the oldest event currently kept in the
  # backfill buffer. This message means that you're likely missing some events that were sent
  # since the last time the client was connected but which were already deleted from the buffer.
  #
  # Note: the {#did}, {#seq} and {#time} properties are always `nil` for `#info` messages.
  #

  class Firehose::InfoMessage < Firehose::Message

    # @return [String] short machine-readable code of the info message
    attr_reader :name

    # @return [String, nil] a human-readable description
    attr_reader :message

    # Message which means that the cursor passed when connecting is older than the oldest event
    # currently kept in the backfill buffer, and that you've likely missed some events that have
    # already been deleted
    OUTDATED_CURSOR = "OutdatedCursor"

    #
    # @private
    # @param type_object [Hash] first decoded CBOR frame with metadata
    # @param data_object [Hash] second decoded CBOR frame with payload
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(type_object, data_object)
      super
      check_if_not_nil :name

      @name = @data_object['name']
      @message = @data_object['message']
    end

    # @return [String] a formatted summary
    def to_s
      (@name || "InfoMessage") + (@message ? ": #{@message}" : "")
    end

    protected

    # @return [Array<Symbol>] list of instance variables to be printed in the {#inspect} output
    def inspectable_variables
      super - [:@did, :@seq]
    end
  end
end
