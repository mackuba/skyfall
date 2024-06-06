module Skyfall
  class IdentityMessage < WebsocketMessage
    def handle
      @data_object['handle']
    end
  end
end
