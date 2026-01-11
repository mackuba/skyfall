require_relative '../firehose'
require_relative 'message'

module Skyfall
  class Firehose::SyncMessage < Firehose::Message
    def rev
      @rev ||= @data_object['rev']
    end
  end
end
