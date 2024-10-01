require_relative '../firehose'

module Skyfall

  #
  # Note: this event type is deprecated and will stop being emitted at some point.
  # You should instead listen for 'identity' events (Skyfall::Firehose::IdentityMessage).
  #
  class Firehose::HandleMessage < Firehose::Message
    def handle
      @data_object['handle']
    end
  end
end
