require_relative '../jetstream'

module Skyfall
  class Jetstream::AccountMessage < Jetstream::Message
    def initialize(json)
      super(:account, json)
    end
  end
end
