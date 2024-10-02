require_relative '../jetstream'

module Skyfall
  class Jetstream::AccountMessage < Jetstream::Message
    def initialize(json)
      super(:account, json)
    end

    def active?
      @json['account']['active']
    end

    def status
      @json['account']['status']&.to_sym
    end
  end
end
