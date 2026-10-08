# frozen_string_literal: true

require_relative '../errors'
require_relative 'message'

module Skyfall

  #
  # Jetstream message sent when the status of an account changes. This can be:
  # 
  # - an account being created, sending its initial state (should be active)
  # - an account being deactivated or suspended
  # - an account being restored back to an active state from deactivation/suspension
  # - an account being deleted (the status returning `:deleted`)
  #

  class JetstreamV2::AccountMessage < JetstreamV2::Message

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      super

      raise DecodeError, "Missing account object" if @payload['account'].nil?
      raise DecodeError, "Invalid account object" unless @payload['account'].is_a?(Hash)
      raise DecodeError, "Missing event details (account.active)" if @payload['account']['active'].nil?
    end

    # @return [Boolean] true if the account is active, false if it's deactivated/suspended etc.
    def active?
      @payload['account']['active']
    end

    # @return [Symbol, nil] for inactive accounts, specifies the exact state; nil for active accounts
    def status
      @payload['account']['status']&.to_sym
    end
  end
end
