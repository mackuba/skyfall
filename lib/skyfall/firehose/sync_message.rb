require_relative '../firehose'

module Skyfall
  class Firehose::SyncMessage < Firehose::Message
    def rev
      @rev ||= @data_object['rev']
    end
  end
end
