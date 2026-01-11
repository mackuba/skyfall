require_relative '../firehose'
require_relative '../label'

module Skyfall

  #
  # A message which includes one or more labels (as {Skyfall::Label}). This type of message
  # is only sent from a `:subscribe_labels` firehose from a labeller service.
  #
  # Note: the {#did} and {#time} properties are always `nil` for `#labels` messages.
  #

  class Firehose::LabelsMessage < Firehose::Message

    # @return [Array<Skyfall::Label>] labels included in the batch
    attr_reader :labels

    #
    # @private
    # @param type_object [Hash] first decoded CBOR frame with metadata
    # @param data_object [Hash] second decoded CBOR frame with payload
    # @raise [DecodeError] if the message doesn't include required data
    #
    def initialize(type_object, data_object)
      super
      raise DecodeError.new("Missing event details") unless @data_object['labels'].is_a?(Array)

      @labels = @data_object['labels'].map { |x| Label.new(x) }
    end

    protected

    # @return [Array<Symbol>] list of instance variables to be printed in the {#inspect} output
    def inspectable_variables
      super - [:@did]
    end
  end
end
