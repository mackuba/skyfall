require_relative '../firehose'
require_relative '../label'

module Skyfall
  class Firehose::LabelsMessage < Firehose::Message
    def labels
      @labels ||= @data_object['labels'].map { |x| Label.new(x) }
    end

    protected

    def inspectable_variables
      super - [:@did]
    end
  end
end
