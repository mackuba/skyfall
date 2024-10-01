require_relative '../jetstream'

module Skyfall
  class Jetstream::AccountMessage < Jetstream::Message
    def initialize(json)
      super
    end

    def type
      :account
    end
  end
end
