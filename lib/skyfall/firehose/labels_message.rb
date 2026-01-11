require_relative '../firehose'
require_relative '../label'

module Skyfall
  class Firehose::LabelsMessage < Firehose::Message

    attr_reader :labels

    def initialize(type_object, data_object)
      super
      raise DecodeError.new("Missing event details") unless @data_object['labels'].is_a?(Array)

      @labels = @data_object['labels'].map { |x| Label.new(x) }
    end

    protected

    def inspectable_variables
      super - [:@did]
    end
  end
end
