module Skyfall
  class DecodeError < StandardError
  end

  class UnsupportedError < StandardError
  end

  class ReactorActiveError < StandardError
    def initialize
      super(
        "An EventMachine reactor thread is already running, but it seems to have been launched by another Stream. " +
        "Skyfall doesn't currently support running two different Stream instances in a single process."
      )
    end
  end

  class SubscriptionError < StandardError
    attr_reader :error_type, :error_message

    def initialize(error_type, error_message = nil)
      @error_type = error_type
      @error_message = error_message

      super("Subscription error: #{error_type}" + (error_message ? " (#{error_message})" : ""))
    end
  end
end
