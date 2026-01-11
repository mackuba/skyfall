require_relative '../errors'
require_relative '../jetstream'
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

  class Jetstream::AccountMessage < Jetstream::Message

    #
    # @param json [Hash] message JSON decoded from the websocket message
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(json)
      raise DecodeError.new("Missing event details (account)") if json['account'].nil? || json['account']['active'].nil?
      super
    end

    # @return [Boolean] true if the account is active, false if it's deactivated/suspended etc.
    def active?
      @json['account']['active']
    end

    # @return [Symbol, nil] for inactive accounts, specifies the exact state; nil for active accounts
    def status
      @json['account']['status']&.to_sym
    end
  end
end
