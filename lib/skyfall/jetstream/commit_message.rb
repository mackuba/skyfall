require_relative '../jetstream'
require_relative '../operation'

module Skyfall
  class Jetstream::CommitMessage < Jetstream::Message
    def initialize(json)
      super
    end

    def type
      :commit
    end

    def raw_record_for_operation(op)
      json['commit']['record']
    end

    def operations
      @operations ||= begin
        [Operation.new(self, {
          'path' => "#{json['commit']['collection']}/#{json['commit']['rkey']}",
          'action' => { 'c' => 'create', 'u' => 'update', 'd' => 'delete' }[json['commit']['type']]
        })]
      end
    end
  end
end
