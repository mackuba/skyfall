require_relative '../firehose'

module Skyfall

  #
  # Note: this event type is deprecated and will stop being emitted at some point.
  # You should instead listen for 'account' events (Skyfall::Firehose::AccountMessage).
  #
  class Firehose::TombstoneMessage < Firehose::Message
  end
end
