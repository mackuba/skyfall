require_relative '../firehose'

module Skyfall
  class Firehose::InfoMessage < Firehose::Message
    attr_reader :name, :message

    OUTDATED_CURSOR = "OutdatedCursor"

    def initialize(type_object, data_object)
      super

      @name = @data_object['name']
      @message = @data_object['message']
    end

    def to_s
      (@name || "InfoMessage") + (@message ? ": #{@message}" : "")
    end

    def inspectable_variables
      super - [:@did, :@seq]
    end
  end
end
