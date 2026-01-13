# frozen_string_literal: true

require_relative '../errors'
require_relative '../jetstream'

require 'time'

module Skyfall

  # @abstract
  # Abstract base class representing a Jetstream message.
  #
  # Actual messages are returned as instances of one of the subclasses of this class,
  # depending on the type of message, most commonly as {Skyfall::Jetstream::CommitMessage}.
  #
  # The {new} method is overridden here so that it can be called with a JSON message from
  # the websocket, and it parses the type from the JSON and builds an instance of a matching
  # subclass.
  # 
  # You normally don't need to call this class directly, unless you're building a custom
  # subclass of {Skyfall::Stream} or reading raw data packets from the websocket through
  # the {Skyfall::Stream#on_raw_message} event handler.

  class Jetstream::Message

    # Type of the message (e.g. `:commit`, `:identity` etc.)
    # @return [Symbol]
    attr_reader :type

    # DID of the account (repo) that the event is sent by
    # @return [String]
    attr_reader :did

    # Server timestamp of the message (in Unix time microseconds), which serves as a cursor
    # when reconnecting; an equivalent of {Skyfall::Firehose::Message#seq} in CBOR firehose
    # messages.
    # @return [Integer]
    attr_reader :time_us

    alias repo did
    alias seq time_us
    alias kind type

    # The raw JSON of the message as parsed from the websocket packet.
    attr_reader :json

    #
    # Parses the JSON data from a websocket message and returns an instance of an appropriate subclass.
    # 
    # {Skyfall::Jetstream::UnknownMessage} is returned if the message type is not recognized.
    #
    # @param data [String] plain text payload of a Jetstream websocket message
    # @return [Skyfall::Jetstream::Message]
    # @raise [DecodeError] if the message doesn't include required data
    #
    def self.new(data)
      json = JSON.parse(data)

      message_class = case json['kind']
        when 'account'  then Jetstream::AccountMessage
        when 'commit'   then Jetstream::CommitMessage
        when 'identity' then Jetstream::IdentityMessage
        else Jetstream::UnknownMessage
      end

      if self != Jetstream::Message && self != message_class
        expected_type = self.name.split('::').last.gsub(/Message$/, '').downcase
        raise DecodeError, "Expected '#{expected_type}' message, got '#{json['kind']}'"
      end

      message = message_class.allocate
      message.send(:initialize, json)
      message
    end

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      %w(kind did time_us).each { |f| raise DecodeError.new("Missing event details (#{f})") if json[f].nil? }

      @json = json
      @type = @json['kind'].to_sym
      @did = @json['did']
      @time_us = @json['time_us']
    end

    #
    # @return [Boolean] true if the message is {Jetstream::UnknownMessage} (of unrecognized type)
    #
    def unknown?
      self.is_a?(Jetstream::UnknownMessage)
    end

    # Returns a record operation included in the message. Only `:commit` messages include
    # operations, but for convenience the method is declared here and returns nil in other messages.
    #
    # @return [nil]
    #
    def operation
      nil
    end

    alias op operation

    # List of operations on records included in the message. Only `:commit` messages include
    # operations, but for convenience the method is declared here and returns an empty array
    # in other messages.
    #
    # @return [Array<Jetstream::Operation>]
    #
    def operations
      []
    end

    #
    # Timestamp decoded from the message.
    #
    # Note: the time is read from the {#time_us} field, which stores the event time as an integer in
    # Unix time microseconds, and which is used as an equivalent of {Skyfall::Firehose::Message#seq}
    # in CBOR firehose messages. This timestamp represents the time when the message was received
    # and stored by Jetstream, which might differ a lot from the `created_at` time saved in the
    # record data, e.g. if user's local time is set incorrectly or if an archive of existing posts
    # was imported from another platform. It will also differ (usually only slightly) from the
    # timestamp of the original CBOR message emitted from the PDS and passed through the relay.
    #
    # @return [Time]
    #
    def time
      @time ||= Time.at(@time_us / 1_000_000.0)
    end
  end
end

# need to be at the end because of a circular dependency

require_relative 'account_message'
require_relative 'commit_message'
require_relative 'identity_message'
require_relative 'unknown_message'
