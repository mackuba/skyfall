module Skyfall
  #
  # Wrapper base class for Skyfall error classes.
  #
  class Error < StandardError
  end

  #
  # Raised when some code is not configured or configured incorrectly.
  #
  class ConfigError < Error
  end

  #
  # Raised when some part of the message being decoded has invalid format.
  #
  class DecodeError < Error
  end

  #
  # Raised when {Stream#connect} is called and there's already another instance of {Stream} or its
  # subclass like {Firehose} that's connected to another websocket.
  #
  # This is currently not supported in Skyfall, because it uses EventMachine behind the scenes, which
  # runs everything on a single "reactor" thread, and there can be only one such reactor thread in
  # a given process. In theory, it should be possible for two connections to run inside a single
  # shared EventMachine event loop, but it would require some more coordination and it might have
  # unexpected side effects - e.g. synchronous work (including I/O and network requests) done during
  # processing of an event from one connection would be blocking the other connection.
  #
  class ReactorActiveError < Error
    def initialize
      super(
        "An EventMachine reactor thread is already running, but it seems to have been launched by another Stream. " +
        "Skyfall doesn't currently support running two different Stream instances in a single process."
      )
    end
  end

  #
  # Raised when the server sends a message which is formatted correctly, but describes some kind of
  # error condition that the server has detected.
  #
  class SubscriptionError < Error

    # @return [String] a short machine-readable error code
    attr_reader :error_type

    # @return [String] a human-readable error message
    attr_reader :error_message

    #
    # @param error_type [String] a short machine-readable error code
    # @param error_message [String, nil] a human-readable error message
    #
    def initialize(error_type, error_message = nil)
      @error_type = error_type
      @error_message = error_message

      super("Subscription error: #{error_type}" + (error_message ? " (#{error_message})" : ""))
    end
  end

  #
  # Raised when the server sends a message which is formatted correctly, but written in a version
  # that's not supported by this library.
  #
  class UnsupportedError < Error
  end
end
