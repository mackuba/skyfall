# frozen_string_literal: true

require_relative 'message'
require_relative '../jetstream/operation'

module Skyfall

  #
  # Jetstream message which includes a single operation on a record in the repo (a record was
  # created, updated or deleted). Most of the messages received from Jetstream are of this type,
  # and this is the type you will usually be most interested in.
  #

  class JetstreamV2::CommitMessage < JetstreamV2::Message

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      super
      check_if_not_nil 'rev', 'collection', 'rkey', 'operation'
    end

    # @return [String] current revision of the repo
    def rev
      @payload['rev']
    end

    # Returns the record operation included in the commit.
    # @return [Jetstream::Operation]
    #
    def operation
      @operation ||= Jetstream::Operation.new(self, @payload)
    end

    alias op operation

    # Returns record operations included in the commit. Currently a `:commit` message from
    # Jetstream always includes exactly one operation, but for compatibility with
    # {Skyfall::Firehose}'s API it's also returned in an array here.
    #
    # @return [Array<Jetstream::Operation>]
    #
    def operations
      [operation]
    end

    alias ops operations
  end
end
