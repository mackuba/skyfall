require_relative '../errors'
require_relative '../jetstream'
require_relative 'operation'

module Skyfall

  #
  # Jetstream message which includes a single operation on a record in the repo (a record was
  # created, updated or deleted). Most of the messages received from Jetstream are of this type,
  # and this is the type you will usually be most interested in.
  #

  class Jetstream::CommitMessage < Jetstream::Message

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      raise DecodeError.new("Missing event details (commit)") if json['commit'].nil?

      %w(collection rkey operation).each { |f| raise DecodeError.new("Missing event details (#{f})") if json['commit'][f].nil? }

      super
    end

    # Returns the record operation included in the commit.
    # @return [Jetstream::Operation]
    #
    def operation
      @operation ||= Jetstream::Operation.new(self, json['commit'])
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
  end
end
