require_relative '../errors'
require_relative '../jetstream'
require_relative 'operation'

module Skyfall
  class Jetstream::CommitMessage < Jetstream::Message
    def initialize(json)
      raise DecodeError.new("Missing event details") if json['commit'].nil?

      super(:commit, json)
    end

    def operations
      @operations ||= [Jetstream::Operation.new(self, json['commit'])]
    end
  end
end
