require_relative '../collection'
require_relative '../jetstream'

module Skyfall
  class Jetstream::Operation
    def initialize(message, json)
      @message = message
      @json = json
    end

    def repo
      @message.repo
    end

    alias did repo

    def path
      @json['collection'] + '/' + @json['rkey']
    end

    def action
      @json['operation'].to_sym
    end

    def collection
      @json['collection']
    end

    def rkey
      @json['rkey']
    end

    def uri
      "at://#{repo}/#{collection}/#{rkey}"
    end

    def cid
      @cid ||= @json['cid'] && CID.from_json(@json['cid'])
    end

    def raw_record
      @json['record']
    end

    def type
      Collection.short_code(collection)
    end

    def inspectable_variables
      instance_variables - [:@message]
    end

    def inspect
      vars = inspectable_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end
  end
end
