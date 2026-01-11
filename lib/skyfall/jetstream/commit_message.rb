require_relative '../errors'
require_relative '../jetstream'
require_relative 'operation'

module Skyfall
  class Jetstream::CommitMessage < Jetstream::Message
    def initialize(json)
      raise DecodeError.new("Missing event details") if json['commit'].nil?
      super
    end

    def operation
      @operation ||= Jetstream::Operation.new(self, json['commit'])
    end

    alias op operation

    def operations
      [operation]
    end
  end
end
