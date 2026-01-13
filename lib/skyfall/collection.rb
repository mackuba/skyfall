# frozen_string_literal: true

module Skyfall

  #
  # This module defines constants for known Bluesky record collection types, and a mapping of those
  # names to symbol short codes which can be used as shorthand when processing events or in
  # Jetstream filters.
  #

  module Collection
    BSKY_PROFILE      = "app.bsky.actor.profile"
    BSKY_ACTOR_STATUS = "app.bsky.actor.status"
    BSKY_FEED         = "app.bsky.feed.generator"
    BSKY_LIKE         = "app.bsky.feed.like"
    BSKY_POST         = "app.bsky.feed.post"
    BSKY_POSTGATE     = "app.bsky.feed.postgate"
    BSKY_REPOST       = "app.bsky.feed.repost"
    BSKY_THREADGATE   = "app.bsky.feed.threadgate"
    BSKY_BLOCK        = "app.bsky.graph.block"
    BSKY_FOLLOW       = "app.bsky.graph.follow"
    BSKY_LIST         = "app.bsky.graph.list"
    BSKY_LISTBLOCK    = "app.bsky.graph.listblock"
    BSKY_LISTITEM     = "app.bsky.graph.listitem"
    BSKY_STARTERPACK  = "app.bsky.graph.starterpack"
    BSKY_VERIFICATION = "app.bsky.graph.verification"
    BSKY_LABELER      = "app.bsky.labeler.service"

    BSKY_NOTIF_DECLARATION = "app.bsky.notification.declaration"
    BSKY_CHAT_DECLARATION  = "chat.bsky.actor.declaration"

    # Mapping of NSID collection names to symbol short codes

    SHORT_CODES = {
      BSKY_ACTOR_STATUS => :bsky_actor_status,
      BSKY_BLOCK        => :bsky_block,
      BSKY_FEED         => :bsky_feed,
      BSKY_FOLLOW       => :bsky_follow,
      BSKY_LABELER      => :bsky_labeler,
      BSKY_LIKE         => :bsky_like,
      BSKY_LIST         => :bsky_list,
      BSKY_LISTBLOCK    => :bsky_listblock,
      BSKY_LISTITEM     => :bsky_listitem,
      BSKY_POST         => :bsky_post,
      BSKY_POSTGATE     => :bsky_postgate,
      BSKY_PROFILE      => :bsky_profile,
      BSKY_REPOST       => :bsky_repost,
      BSKY_STARTERPACK  => :bsky_starterpack,
      BSKY_THREADGATE   => :bsky_threadgate,
      BSKY_VERIFICATION => :bsky_verification,
      BSKY_CHAT_DECLARATION => :bsky_chat_declaration,
      BSKY_NOTIF_DECLARATION => :bsky_notif_declaration
    }

    # Returns a symbol short code for a given collection NSID, or `:unknown`
    # if NSID is not on the list.
    # @param collection [String] collection NSID
    # @return [Symbol] short code or :unknown

    def self.short_code(collection)
      SHORT_CODES[collection] || :unknown
    end

    # Returns a collection NSID assigned to a given short code symbol, if one is defined.
    # @param code [Symbol] one of the symbols listed in {SHORT_CODES}
    # @return [String, nil] assigned NSID string, or nil when code is not known

    def self.from_short_code(code)
      SHORT_CODES.detect { |k, v| v == code }&.first
    end
  end
end
