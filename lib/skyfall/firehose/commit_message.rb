require_relative '../car_archive'
require_relative '../cid'
require_relative '../firehose'
require_relative 'operation'

module Skyfall

  #
  # Firehose message which includes one or more operations on records in the repo (a record was
  # created, updated or deleted). In most cases this is a single record operation.
  #
  # Most of the messages received from the firehose are of this type, and this is the type you
  # will usually be most interested in.
  #

  class Firehose::CommitMessage < Firehose::Message

    # @return [CID] CID (Content Identifier) of the commit
    def commit
      @commit ||= @data_object['commit'] && CID.from_cbor_tag(@data_object['commit'])
    end

    # @return [Skyfall::CarArchive] commit data in the form of a parsed CAR archive
    def blocks
      @blocks ||= CarArchive.new(@data_object['blocks'])
    end

    # @return [Array<Firehose::Operation>] record operations (usually one) included in the commit
    def operations
      @operations ||= @data_object['ops'].map { |op| Firehose::Operation.new(self, op) }
    end

    # Looks up record data assigned to a given operation in the commit's CAR archive.
    # @param op [Firehose::Operation]
    # @return [Hash, nil]
    def raw_record_for_operation(op)
      op.cid && blocks.section_with_cid(op.cid)
    end
  end
end
