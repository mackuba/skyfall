require_relative '../errors'
require_relative '../jetstream'

module Skyfall
  class Jetstream::AccountMessage < Jetstream::Message
    def initialize(json)
      raise DecodeError.new("Missing event details") if json['account'].nil?
      super
    end

    def active?
      @json['account']['active']
    end

    def status
      @json['account']['status']&.to_sym
    end
  end
end
