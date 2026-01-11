require_relative 'errors'
require 'time'

module Skyfall

  #
  # A single label emitted from the "subscribeLabels" firehose of a labeller service.
  #
  # The label assigns some specific value - from a list of available values defined by this
  # labeller - to a specific target (at:// URI or a DID). In general, this will usually be either
  # a "badge" that a user requested to be assigned to themselves from a fun/informative labeller,
  # or some kind of (likely negative) label assigned to a user or post by a moderation labeller.
  #
  # You generally don't need to create instances of this class manually, but will receive them
  # from {Skyfall::Firehose} that's connected to `:subscribe_labels` in the {Stream#on_message}
  # callback handler (wrapped in a {Skyfall::Firehose::LabelsMessage}).
  #

  class Label

    # @return [Hash] the label's JSON data
    attr_reader :data

    #
    # @param data [Hash] raw label JSON
    # @raise [Skyfall::DecodeError] if the data has an invalid format
    # @raise [Skyfall::UnsupportedError] if the label is in an unsupported future version
    #
    def initialize(data)
      @data = data

      raise DecodeError.new("Missing version: #{data}") unless data.has_key?('ver')
      raise DecodeError.new("Invalid version: #{ver}") unless ver.is_a?(Integer) && ver >= 1
      raise UnsupportedError.new("Unsupported version: #{ver}") unless ver == 1

      raise DecodeError.new("Missing source: #{data}") unless data.has_key?('src')
      raise DecodeError.new("Invalid source: #{src}") unless src.is_a?(String) && src.start_with?('did:')

      raise DecodeError.new("Missing uri: #{data}") unless data.has_key?('uri')
      raise DecodeError.new("Invalid uri: #{uri}") unless uri.is_a?(String)
      raise DecodeError.new("Invalid uri: #{uri}") unless uri.start_with?('at://') || uri.start_with?('did:')
    end

    # @return [Integer] label format version number
    def version
      @data['ver']
    end

    # DID of the labelling authority (the labeller service).
    # @return [String]
    def authority
      @data['src']
    end

    # AT URI or DID of the labelled subject (e.g. a user or post).
    # @return [String]
    def subject
      @data['uri']
    end

    # @return [CID, nil] CID of the specific version of the subject that this label applies to
    def cid
      @cid ||= @data['cid'] && CID.from_json(@data['cid'])
    end

    # @return [String] label value
    def value
      @data['val']
    end

    # @return [Boolean] if true, then this is a negation (delete) of an existing label
    def negation?
      !!@data['neg']
    end

    # @return [Time] timestamp when the label was created
    def created_at
      @created_at ||= Time.parse(@data['cts'])
    end

    # @return [Time, nil] optional timestamp when the label expires
    def expires_at
      @expires_at ||= @data['exp'] && Time.parse(@data['exp'])
    end

    alias ver version
    alias src authority
    alias uri subject
    alias val value
    alias neg negation?
    alias cts created_at
    alias exp expires_at
  end
end
