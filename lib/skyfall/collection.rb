module Skyfall
  module Collection
    BSKY_PROFILE     = "app.bsky.actor.profile"
    BSKY_FEED        = "app.bsky.feed.generator"
    BSKY_LIKE        = "app.bsky.feed.like"
    BSKY_POST        = "app.bsky.feed.post"
    BSKY_POSTGATE    = "app.bsky.feed.postgate"
    BSKY_REPOST      = "app.bsky.feed.repost"
    BSKY_THREADGATE  = "app.bsky.feed.threadgate"
    BSKY_BLOCK       = "app.bsky.graph.block"
    BSKY_FOLLOW      = "app.bsky.graph.follow"
    BSKY_LIST        = "app.bsky.graph.list"
    BSKY_LISTBLOCK   = "app.bsky.graph.listblock"
    BSKY_LISTITEM    = "app.bsky.graph.listitem"
    BSKY_STARTERPACK = "app.bsky.graph.starterpack"
    BSKY_LABELER     = "app.bsky.labeler.service"

    BSKY_CHAT_DECLARATION = "chat.bsky.actor.declaration"

    def self.short_code(collection)
      case collection
      when BSKY_BLOCK       then :bsky_block
      when BSKY_FEED        then :bsky_feed
      when BSKY_FOLLOW      then :bsky_follow
      when BSKY_LABELER     then :bsky_labeler
      when BSKY_LIKE        then :bsky_like
      when BSKY_LIST        then :bsky_list
      when BSKY_LISTBLOCK   then :bsky_listblock
      when BSKY_LISTITEM    then :bsky_listitem
      when BSKY_POST        then :bsky_post
      when BSKY_POSTGATE    then :bsky_postgate
      when BSKY_PROFILE     then :bsky_profile
      when BSKY_REPOST      then :bsky_repost
      when BSKY_STARTERPACK then :bsky_starterpack
      when BSKY_THREADGATE  then :bsky_threadgate
      when BSKY_CHAT_DECLARATION then :bsky_chat_declaration
      else :unknown
      end
    end
  end
end
