require_relative '../jetstream'

module Skyfall
  class Jetstream::UnknownMessage < Jetstream::Message
    def initialize(json)
      super(:unknown, json)
    end
  end
end
