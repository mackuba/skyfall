require_relative 'collection'

module Skyfall
  class Operation
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
      @raw_record ||= cid && @message.blocks.section_with_cid(cid)
    end

    def type
      case collection
      when Collection::BSKY_BLOCK       then :bsky_block
      when Collection::BSKY_FEED        then :bsky_feed
      when Collection::BSKY_FOLLOW      then :bsky_follow
      when Collection::BSKY_LABELER     then :bsky_labeler
      when Collection::BSKY_LIKE        then :bsky_like
      when Collection::BSKY_LIST        then :bsky_list
      when Collection::BSKY_LISTBLOCK   then :bsky_listblock
      when Collection::BSKY_LISTITEM    then :bsky_listitem
      when Collection::BSKY_POST        then :bsky_post
      when Collection::BSKY_POSTGATE    then :bsky_postgate
      when Collection::BSKY_PROFILE     then :bsky_profile
      when Collection::BSKY_REPOST      then :bsky_repost
      when Collection::BSKY_STARTERPACK then :bsky_starterpack
      when Collection::BSKY_THREADGATE  then :bsky_threadgate
      when Collection::BSKY_CHAT_DECLARATION then :bsky_chat_declaration
      else :unknown
      end
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
