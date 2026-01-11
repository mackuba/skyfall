require_relative '../firehose'

module Skyfall

  #
  # Firehose message sent when the status of an account changes. This can be:
  # 
  # - an account being created, sending its initial state (should be active)
  # - an account being deactivated or suspended
  # - an account being restored back to an active state from deactivation/suspension
  # - an account being deleted (the status returning `:deleted`)
  #

  class Firehose::AccountMessage < Firehose::Message

    #
    # @private
    # @param type_object [Hash] first decoded CBOR frame with metadata
    # @param data_object [Hash] second decoded CBOR frame with payload
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(type_object, data_object)
      super
      raise DecodeError.new("Missing event details") if @data_object['active'].nil?

      @active = @data_object['active']
      @status = @data_object['status']&.to_sym
    end

    # @return [Boolean] true if the account is active, false if it's deactivated/suspended etc.
    def active?
      @active
    end

    # @return [Symbol, nil] for inactive accounts, specifies the exact state; nil for active accounts
    attr_reader :status
  end
end
