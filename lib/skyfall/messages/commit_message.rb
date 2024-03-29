require_relative '../car_archive'
require_relative '../cid'
require_relative '../operation'

module Skyfall
  class CommitMessage < WebsocketMessage
    def commit
      @commit ||= @data_object['commit'] && CID.from_cbor_tag(@data_object['commit'])
    end

    def prev
      @prev ||= @data_object['prev'] && CID.from_cbor_tag(@data_object['prev'])
    end

    def blocks
      @blocks ||= CarArchive.new(@data_object['blocks'])
    end

    def operations
      @operations ||= @data_object['ops'].map { |op| Operation.new(self, op) }
    end
  end
end
