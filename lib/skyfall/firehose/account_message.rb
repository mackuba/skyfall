require_relative '../firehose'

module Skyfall
  class Firehose::AccountMessage < Firehose::Message
    def active?
      @data_object['active']
    end

    def status
      @data_object['status']&.to_sym
    end
  end
end
