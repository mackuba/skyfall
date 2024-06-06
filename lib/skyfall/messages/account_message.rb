module Skyfall
  class AccountMessage < WebsocketMessage
    def active?
      @data_object['active']
    end

    def status
      @data_object['status']&.to_sym
    end
  end
end
