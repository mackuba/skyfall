module Skyfall

  #
  # Note: this event type is deprecated and will stop being emitted at some point.
  # You should instead listen for 'identity' events (Skyfall::IdentityMessage).
  #
  class HandleMessage < WebsocketMessage
    def handle
      @data_object['handle']
    end
  end
end
