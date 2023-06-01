require_relative 'collection'

module Skyfall
  class Operation
    attr_reader :repo, :path, :action, :cid

    def initialize(repo, path, action, cid, record)
      @repo = repo
      @path = path
      @action = action.to_sym
      @cid = cid
      @record = record
    end

    def raw_record
      @record
    end

    def uri
      "at://#{repo}/#{path}"
    end

    def collection
      path.split('/').first
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
      else :unknown
      end
    end
  end
end
