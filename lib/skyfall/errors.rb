module Skyfall
  class DecodeError < StandardError
  end

  class UnsupportedError < StandardError
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
