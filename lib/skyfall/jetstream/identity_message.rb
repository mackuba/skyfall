require_relative '../jetstream'

module Skyfall
  class Jetstream::IdentityMessage < Jetstream::Message
    def initialize(json)
      super(:identity, json)
    end
  end
end
