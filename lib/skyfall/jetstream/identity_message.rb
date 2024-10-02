require_relative '../errors'
require_relative '../jetstream'

module Skyfall
  class Jetstream::IdentityMessage < Jetstream::Message
    def initialize(json)
      raise DecodeError.new("Missing event details") if json['identity'].nil?

      super(:identity, json)
    end

    def handle
      @json['identity']['handle']
    end
  end
end
