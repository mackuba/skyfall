module Skyfall

  #
  # Note: this event type is deprecated and will stop being emitted at some point.
  # You should instead listen for 'account' events (Skyfall::AccountMessage).
  #
  class TombstoneMessage < WebsocketMessage
  end
end
