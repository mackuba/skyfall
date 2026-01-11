require_relative '../collection'
require_relative '../firehose'

module Skyfall
  class Firehose::Operation
    def initialize(message, json)
      @message = message
      @json = json
    end

    def repo
      @message.repo
    end

    alias did repo

    def path
      @json['path']
    end

    def action
      @json['action'].to_sym
    end

    def collection
      @json['path'].split('/')[0]
    end

    def rkey
      @json['path'].split('/')[1]
    end

    def uri
      "at://#{repo}/#{path}"
    end

    def cid
      @cid ||= @json['cid'] && CID.from_cbor_tag(@json['cid'])
    end

    def raw_record
      @raw_record ||= @message.raw_record_for_operation(self)
    end

    def type
      Collection.short_code(collection)
    end

    def inspect
      vars = inspectable_variables.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
      "#<#{self.class}:0x#{object_id} #{vars}>"
    end

    private

    def inspectable_variables
      instance_variables - [:@message]
    end
  end
end
