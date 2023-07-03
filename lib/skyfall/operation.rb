require_relative 'collection'

module Skyfall
  class Operation
    attr_reader :path, :action, :cid

    def initialize(message, path, action, cid)
      @message = message
      @path = path
      @action = action.to_sym
      @cid = cid
    end

    def repo
      @message.repo
    end

    def raw_record
      @raw_record ||= (@cid && @message.blocks.sections.detect { |s| s.cid == @cid }.body)
    end

    def uri
      "at://#{repo}/#{path}"
    end

    def collection
      path.split('/')[0]
    end

    def rkey
      path.split('/')[1]
    end

    def type
      case collection
      when Collection::BSKY_POST then :bsky_post
      when Collection::BSKY_LIKE then :bsky_like
      when Collection::BSKY_FOLLOW then :bsky_follow
      when Collection::BSKY_REPOST then :bsky_repost
      when Collection::BSKY_BLOCK then :bsky_block
      when Collection::BSKY_PROFILE then :bsky_profile
      when Collection::BSKY_LISTITEM then :bsky_listitem
      when Collection::BSKY_FEED then :bsky_feed
      else :unknown
      end
    end
  end
end
