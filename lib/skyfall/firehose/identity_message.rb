require_relative '../firehose'

module Skyfall
  class Firehose::IdentityMessage < Firehose::Message
    def handle
      @data_object['handle']
    end
  end
end
