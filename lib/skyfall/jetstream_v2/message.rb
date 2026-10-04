# frozen_string_literal: true

require_relative '../errors'
require_relative '../jetstream_v2'

require 'json'
require 'time'

module Skyfall

  # @abstract
  # Abstract base class representing a Jetstream v2 message.
  #
  # Actual messages are returned as instances of one of the subclasses of this class,
  # depending on the type of message, most commonly as {Skyfall::JetstreamV2::CommitMessage}.
  #
  # The {new} method is overridden here so that it can be called with a JSON message from
  # the websocket, and it parses the type from the JSON and builds an instance of a matching
  # subclass.
  # 
  # You normally don't need to call this class directly, unless you're building a custom
  # subclass of {Skyfall::Stream} or reading raw data packets from the websocket through
  # the {Skyfall::Stream#on_raw_message} event handler.

  class JetstreamV2::Message

    # Type of the message (e.g. `:commit`, `:identity` etc.)
    # @return [Symbol]
    attr_reader :type

    # DID of the account (repo) that the event is sent by
    # @return [String, nil]
    attr_reader :did

    # Cursor value of the event to be used when reconnecting (a sequential number).
    # @return [Integer, nil]
    attr_reader :seq

    alias cursor seq
    alias repo did
    alias kind type

    # The raw JSON of the message as parsed from the websocket packet.
    # @return [Hash]
    attr_reader :json

    #
    # Parses the JSON data from a websocket message and returns an instance of an appropriate subclass.
    # 
    # {Skyfall::JetstreamV2::UnknownMessage} is returned if the message type is not recognized.
    #
    # @param data [String] plain text payload of a Jetstream websocket message
    # @return [Skyfall::JetstreamV2::Message]
    # @raise [Skyfall::DecodeError] if the message is malformed or doesn't include required data
    # @raise [Skyfall::SubscriptionError] if the data contains an error message from the server
    #
    def self.new(data)
      json = JSON.parse(data)
      raise DecodeError, "Expected a JSON object" unless json.is_a?(Hash)

      if json['$type'] == 'error'
        raise SubscriptionError.new(json['error'], json['message'])
      elsif json['$type'] != 'message'
        raise DecodeError, "Unknown Jetstream v2 frame type: #{json['$type'].inspect}"
      end

      raise DecodeError, "Missing message payload" if json['payload'].nil?
      raise DecodeError, "Invalid message payload" unless json['payload'].is_a?(Hash)

      event_type = json['payload']['$type']
      raise DecodeError, "Invalid event type: #{event_type.inspect}" unless event_type.is_a?(String)

      parts = event_type.split('#')
      prefix = 'network.bsky.jetstream.subscribeEvents'
      raise DecodeError, "Invalid event type: #{event_type.inspect}" unless parts.length == 2 && parts[0] == prefix

      kind = parts[1]

      message_class = case kind
        when 'account'  then JetstreamV2::AccountMessage
        when 'commit'   then JetstreamV2::CommitMessage
        when 'identity' then JetstreamV2::IdentityMessage
        when 'sync'     then JetstreamV2::SyncMessage
        when 'info'     then JetstreamV2::InfoMessage
        else JetstreamV2::UnknownMessage
      end

      if self != JetstreamV2::Message && self != message_class
        expected_type = self.name.split('::').last.gsub(/Message$/, '').downcase
        raise DecodeError, "Expected '#{expected_type}' message, got '#{kind}'"
      end

      message = message_class.allocate
      message.send(:initialize, json)
      message
    rescue JSON::ParserError => e
      raise DecodeError, "Invalid JSON message: #{e.message}"
    end

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      @json = json
      @payload = json['payload']

      @type = @payload['$type'].split('#')[1].to_sym
      @did = @payload['did']
      @seq = @payload['seq']

      unless @type == :info
        check_if_not_nil 'did', 'seq', 'time'
        raise DecodeError, "Invalid event sequence number" unless @seq.is_a?(Integer)
      end
    end

    #
    # @return [Boolean] true if the message is {JetstreamV2::UnknownMessage} (of unrecognized type)
    #
    def unknown?
      self.is_a?(JetstreamV2::UnknownMessage)
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
    # an operation and only one, but for symmetry with {Skyfall::Firehose::Message} the array method is
    # also included here and returns either a one-item array in commit messages or an empty array in others.
    #
    # @return [Array<JetstreamV2::Operation>]
    #
    def operations
      []
    end

    alias ops operations

    # Timestamp decoded from the message.
    #
    # Note: this timestamp represents the time when the message was received and stored by Jetstream,
    # which might differ a lot from the `created_at` time saved in the record data, e.g. if user's
    # local time is set incorrectly or if an archive of existing posts was imported from another
    # platform. It will also differ (usually only slightly) from the timestamp of the original CBOR
    # message emitted from the PDS and passed through the relay.
    #
    # @return [Time, nil]
    #
    def time
      @time ||= parse_time(@payload['time'])
    end

    # Timestamp of the event in Unix microseconds (see {#time}).
    #
    # Unlike in Jetstream v1, the standard cursor used in Jetstream v2 API is the {#seq} / {#cursor}
    # value, which is a sequential number like in a CBOR firehose, although the API also accepts
    # a microsecond timestamp returned from this method as a cursor when reconnecting.
    # 
    # @return [Integer, nil]
    #
    def time_us
      time && (time.to_r * 1_000_000).to_i
    end

    # The `witnessed_at` timestamp of when the event was stored on the Jetstream server. Currently,
    # this is always the same as {#time} (may be nil on Jetstream servers running older versions of v2).
    #
    # @return [Time, nil]
    #
    def witnessed_at
      @witnessed_at ||= parse_time(@payload['witnessedAt'])
    end


    private

    def check_if_not_nil(*fields)
      fields.each do |field|
        raise DecodeError, "Missing event details (#{field})" if @payload[field].nil?
      end
    end

    def parse_time(timestamp)
      timestamp && Time.iso8601(timestamp)
    end

    # Much faster version for Ruby 3.2+

    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.2')
      def parse_time(timestamp)
        timestamp && Time.new(timestamp)
      end
    end
  end
end

# need to be at the end because of a circular dependency

require_relative 'account_message'
require_relative 'commit_message'
require_relative 'identity_message'
require_relative 'sync_message'
require_relative 'info_message'
require_relative 'unknown_message'
