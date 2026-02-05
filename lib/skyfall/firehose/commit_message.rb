# frozen_string_literal: true

require_relative '../car_archive'
require_relative '../cid'
require_relative '../firehose'
require_relative 'message'
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

    #
    # @private
    # @param type_object [Hash] first decoded CBOR frame with metadata
    # @param data_object [Hash] second decoded CBOR frame with payload
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(type_object, data_object)
      super
      check_if_not_nil 'seq', 'repo', 'commit', 'blocks', 'ops', 'time', 'rev'
    end

    # @return [String] current revision of the repo
    def rev
      @data_object['rev']
    end

    # @return [String, nil] revision of the previous commit in the repo
    def since
      @data_object['since']
    end

    # @return [CID, nil] CID (Content Identifier) of data of the previous commit in the repo
    def prev_data
      @prev_data ||= CID.from_cbor_tag(@data_object['prevData'])
    end

    # @return [CID] CID (Content Identifier) of the commit
    def commit
      @commit ||= CID.from_cbor_tag(@data_object['commit'])
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
