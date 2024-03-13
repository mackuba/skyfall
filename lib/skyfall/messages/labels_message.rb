require_relative 'websocket_message'
require_relative '../label'

module Skyfall
  class LabelsMessage
    using Skyfall::Extensions

    attr_reader :type_object, :data_object
    attr_reader :type, :seq

    def initialize(type_object, data_object)
      @type_object = type_object
      @data_object = data_object

      @type = @type_object['t'][1..-1].to_sym
      @seq = @data_object['seq']
    end

    def labels
      @labels ||= @data_object['labels'].map { |x| Label.new(x) }
    end
  end
end
