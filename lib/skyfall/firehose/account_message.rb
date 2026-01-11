require_relative '../firehose'

module Skyfall
  class Firehose::AccountMessage < Firehose::Message
    def initialize(type_object, data_object)
      super
      raise DecodeError.new("Missing event details") if @data_object['active'].nil?

      @active = @data_object['active']
      @status = @data_object['status']&.to_sym
    end

    def active?
      @active
    end

    attr_reader :status
  end
end
