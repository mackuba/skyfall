require_relative '../jetstream'

module Skyfall
  class Jetstream::IdentityMessage < Jetstream::Message
    def initialize(json)
      super
    end

    def type
      :identity
    end
  end
end
