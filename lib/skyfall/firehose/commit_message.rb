require_relative '../car_archive'
require_relative '../cid'
require_relative '../firehose'
require_relative 'operation'

module Skyfall
  class Firehose::CommitMessage < Firehose::Message
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
      @operations ||= @data_object['ops'].map { |op| Firehose::Operation.new(self, op) }
    end

    def raw_record_for_operation(op)
      op.cid && blocks.section_with_cid(op.cid)
    end
  end
end
