module Skyfall
  class HandleMessage < WebsocketMessage
    def handle
      @data_object['handle']
    end
  end
end
