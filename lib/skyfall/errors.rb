module Skyfall
  class Error < StandardError
  end

  class DecodeError < Error
  end

  class UnsupportedError < Error
  end

  class ReactorActiveError < Error
    def initialize
      super(
        "An EventMachine reactor thread is already running, but it seems to have been launched by another Stream. " +
        "Skyfall doesn't currently support running two different Stream instances in a single process."
      )
    end
  end

  class SubscriptionError < Error
    attr_reader :error_type, :error_message

    def initialize(error_type, error_message = nil)
      @error_type = error_type
      @error_message = error_message

      super("Subscription error: #{error_type}" + (error_message ? " (#{error_message})" : ""))
    end
  end
end
