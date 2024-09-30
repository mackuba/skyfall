require_relative '../errors'
require 'time'

module Skyfall
  class JetstreamMessage
    attr_reader :did, :json, :seq
    alias repo did

    class AccountMessage < JetstreamMessage
      def initialize(json)
        super
      end

      def type
        :account
      end
    end

    class CommitMessage < JetstreamMessage
      def initialize(json)
        super
      end

      def type
        :commit
      end

      def operations
        @operations ||= begin
          json = @json
          op = Operation.new(self, {
            'path' => "#{json['commit']['collection']}/#{json['commit']['rkey']}",
            'action' => { 'c' => 'create', 'u' => 'update', 'd' => 'delete' }[json['commit']['type']]
          })
          op.singleton_class.define_method(:raw_record) do
            json['commit']['record']
          end
          [op]
        end
      end
    end

    class IdentityMessage < JetstreamMessage
      def initialize(json)
        super
      end

      def type
        :identity
      end
    end

    def self.new(data)
      json = JSON.parse(data)

      message_class = case json['type']
        when 'acc' then AccountMessage
        when 'com' then CommitMessage
        when 'id' then IdentityMessage
        else UnknownMessage
      end

      message = message_class.allocate
      message.send(:initialize, json)
      message
    end

    def initialize(json)
      @json = json
      @did = @json['did']
      @seq = @json['time_us']
    end

    def operations
      []
    end

    def time
      @time ||= @json['time_us'] && Time.at(@json['time_us'] / 1000.0)
    end
  end
end
