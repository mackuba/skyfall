require_relative '../errors'
require_relative '../jetstream'

require 'time'

module Skyfall
  class Jetstream::Message
    require_relative 'account_message'
    require_relative 'commit_message'
    require_relative 'identity_message'
    require_relative 'unknown_message'

    attr_reader :did, :type, :time_us
    alias repo did
    alias seq time_us

    # :nodoc: - consider this as semi-private API
    attr_reader :json

    def self.new(data)
      json = JSON.parse(data)

      message_class = case json['type']
        when 'acc' then Jetstream::AccountMessage
        when 'com' then Jetstream::CommitMessage
        when 'id'  then Jetstream::IdentityMessage
        else Jetstream::UnknownMessage
      end

      message = message_class.allocate
      message.send(:initialize, json)
      message
    end

    def initialize(type, json)
      @type = type
      @json = json
      @did = @json['did']
      @time_us = @json['time_us']
    end

    def operations
      []
    end

    def time
      @time ||= @json['time_us'] && Time.at(@json['time_us'] / 1_000_000.0)
    end
  end
end
