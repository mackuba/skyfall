require_relative '../jetstream'
require_relative 'operation'

module Skyfall
  class Jetstream::CommitMessage < Jetstream::Message
    def initialize(json)
      super
    end

    def type
      :commit
    end

    def operations
      @operations ||= [Jetstream::Operation.new(self, json['commit'])]
    end
  end
end
