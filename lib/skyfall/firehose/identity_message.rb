require_relative '../firehose'

module Skyfall

  #
  # Firehose message sent when a new DID is created or when the details of someone's DID document
  # are changed (usually either a handle change or a migration to a different PDS). The message
  # should include currently assigned handle (though the field is not required).
  #
  # Note: the message is originally emitted from the account's PDS and is passed as is by relays,
  # which means you can't fully trust that the handle is actually correctly assigned to the DID
  # and verified by DNS or well-known. To confirm that, use `DID.resolve_handle` from
  # [DIDKit](https://ruby.sdk.blue/didkit/).
  #

  class Firehose::IdentityMessage < Firehose::Message

    # @return [String, nil] current handle assigned to the DID
    def handle
      @data_object['handle']
    end
  end
end
