require_relative '../jetstream'

module Skyfall
  class Jetstream::IdentityMessage < Jetstream::Message
    def initialize(json)
      super(:identity, json)
    end

    def handle
      @json['identity']['handle']
    end
  end
end
