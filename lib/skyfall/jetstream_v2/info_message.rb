# frozen_string_literal: true

require_relative 'message'

module Skyfall

  #
  # An informational message from the Jetstream service itself, unrelated to any repos.
  #
  # Currently there are two types of info messages defined:
  #
  # * `"OutdatedCursor"`, sent when the client connects with a timestamp cursor that is older than
  #   the oldest event currently kept in the backfill buffer, which means that you're likely missing
  #   some events that were sent since the last time the client was connected but which were already
  #   deleted from the buffer
  # * `"FutureCursor"`, sent when the client connects with a seq cursor that is higher than the
  #   current latest cursor on the server
  #
  # Note: the {#did}, {#seq}, {#time} and {#time_us} properties are always `nil` for `#info` messages.
  #

  class JetstreamV2::InfoMessage < JetstreamV2::Message

    # @return [String] short machine-readable code of the info message
    attr_reader :name

    # @return [String, nil] a human-readable description
    attr_reader :message

    # Message which means that the timestamp cursor passed when connecting is older than the oldest event
    # currently kept in the backfill buffer, and that you've likely missed some events that have
    # already been deleted.
    OUTDATED_CURSOR = 'OutdatedCursor'

    # Message which means that the seq cursor passed when connecting is higher than the
    # current latest cursor on the server.
    FUTURE_CURSOR = 'FutureCursor'

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      super
      check_if_not_nil 'name'

      @name = @payload['name']
      @message = @payload['message']
    end

    # @return [String] a formatted summary
    def to_s
      @message ? "#{@name}: #{@message}" : @name
    end
  end
end
