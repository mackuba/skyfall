# frozen_string_literal: true

require_relative '../collection'
require_relative '../firehose'

module Skyfall

  #
  # A single record operation from a firehose commit event. An operation is a new record being
  # created, or an existing record modified or deleted. It includes the URI and other details of
  # the record in question, type of the action taken, and record data for "created" and "update"
  # actions.
  #
  # Note: when a record is deleted, the previous record data is *not* included in the commit, only
  # its URI. This means that if you're tracking records which are referencing other records, e.g.
  # follow, block, or like records, you need to store information about this referencing record
  # including an URI or rkey, because in case of a delete, you will not get information about which
  # post was unliked or which account was unfollowed, only which like/follow record was deleted.
  #
  # At the moment, Skyfall doesn't parse the record data into any rich models specific for a given
  # record type with a convenient API, but simply returns them as `Hash` objects (see {#raw_record}).
  # In the future, a separate `#record` method might be added which returns a parsed record model.
  #

  class Firehose::Operation

    #
    # @param message [Skyfall::Firehose::Message] commit message the operation is included in
    # @param json [Hash] operation data
    #
    def initialize(message, json)
      @message = message
      @json = json
    end

    # @return [String] DID of the account/repository in which the operation happened
    def repo
      @message.repo
    end

    alias did repo

    # @return [String] path part of the record URI (collection + rkey)
    # @deprecated Use {#collection} + {#rkey}
    def path
      @@path_warning_printed ||= false

      unless @@path_warning_printed
        $stderr.puts "Warning: Skyfall::Firehose::Operation#path is deprecated - use #collection + #rkey"
        @@path_warning_printed = true
      end

      @json['path']
    end

    # @return [Symbol] type of the operation (`:create`, `:update` or `:delete`)
    def action
      @json['action'].to_sym
    end

    # @return [String] record collection NSID
    def collection
      @json['path'].split('/')[0]
    end

    # @return [String] record rkey
    def rkey
      @json['path'].split('/')[1]
    end

    # @return [String] full AT URI of the record
    def uri
      "at://#{repo}/#{@json['path']}"
    end

    # @return [CID, nil] CID (Content Identifier) of the record (nil for delete operations)
    def cid
      @cid ||= @json['cid'] && CID.from_cbor_tag(@json['cid'])
    end

    # @return [Hash, nil] record data as a plain Ruby Hash (nil for delete operations)
    def raw_record
      @raw_record ||= @message.raw_record_for_operation(self)
    end

    # Symbol short code of the collection, like `:bsky_post`. If the collection NSID is not
    # recognized, the type is `:unknown`. The full NSID is always available through the
    # `#collection` property.
    #
    # @return [Symbol]
    # @see Skyfall::Collection
    #
    def type
      Collection.short_code(collection)
    end

    # Returns a string with a representation of the object for debugging purposes.
    # @return [String]
    def inspect
      vars = inspectable_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end

    private

    def inspectable_variables
      instance_variables - [:@message]
    end
  end
end
