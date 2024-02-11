#!/usr/bin/env ruby

# Example: send push notifications to a client app about interactions with a given account.

# load skyfall from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'json'
require 'open-uri'
require 'skyfall'

monitored_did = ARGV[0]

if monitored_did.to_s.empty?
  puts "Usage: #{$PROGRAM_NAME} <monitored_did>"
  exit 1
elsif monitored_did !~ /^did:plc:[a-z0-9]{24}$/
  puts "Not a valid DID: #{monitored_did}"
  exit 1
end

class InvalidURIException < StandardError
  def initialize(uri)
    super("Invalid AT URI: #{uri}")
  end
end

class AtURI
  attr_reader :did, :collection, :rkey

  def initialize(uri)
    if uri =~ /\Aat:\/\/(did:[\w]+:[\w\.\-]+)\/([\w\.]+)\/([\w\-]+)\z/
      @did = $1
      @collection = $2
      @rkey = $3
    else
      raise InvalidURIException, uri
    end
  end
end

class NotificationEngine
  def initialize(user_did)
    @user_did = user_did
  end

  def connect
    @sky = Skyfall::Stream.new('bsky.network', :subscribe_repos)

    @sky.on_connect { puts "Connected, monitoring #{@user_did}" }
    @sky.on_disconnect { puts "Disconnected" }
    @sky.on_reconnect { puts "Reconnecting..." }
    @sky.on_error { |e| puts "ERROR: #{e}" }

    @sky.on_message do |msg|
      process_message(msg)
    end

    @sky.connect
  end

  def disconnect
    @sky.disconnect
  end

  def process_message(msg)
    # we're only interested in repo commit messages
    return if msg.type != :commit

    # ignore user's own actions
    return if msg.repo == @user_did

    msg.operations.each do |op|
      next if op.action != :create

      begin
        case op.type
        when :bsky_post
          process_post(msg, op)
        when :bsky_like
          process_like(msg, op)
        when :bsky_repost
          process_repost(msg, op)
        when :bsky_follow
          process_follow(msg, op)
        end
      rescue StandardError => e
        puts "Error: #{e}"
      end
    end
  end


  # posts

  def process_post(msg, op)
    data = op.raw_record

    if reply = data['reply']
      # check for replies (direct only)
      if reply['parent'] && reply['parent']['uri']
        parent_uri = AtURI.new(reply['parent']['uri'])

        if parent_uri.did == @user_did
          send_reply_notification(msg, op)
        end
      end
    end

    if embed = data['embed']
      # check for quotes
      if embed['record'] && embed['record']['uri']
        quoted_uri = AtURI.new(embed['record']['uri'])

        if quoted_uri.did == @user_did
          send_quote_notification(msg, op)
        end
      end

      # second type of quote (recordWithMedia)
      if embed['record'] && embed['record']['record'] && embed['record']['record']['uri']
        quoted_uri = AtURI.new(embed['record']['record']['uri'])

        if quoted_uri.did == @user_did
          send_quote_notification(msg, op)
        end
      end
    end

    if facets = data['facets']
      # check for mentions
      if facets.any? { |f| f['features'] && f['features'].any? { |x| x['did'] == @user_did }}
        send_mention_notification(msg, op)
      end
    end
  end

  def send_reply_notification(msg, op)
    handle = get_user_handle(msg.repo)

    send_push("@#{handle} replied:", op.raw_record)
  end

  def send_quote_notification(msg, op)
    handle = get_user_handle(msg.repo)

    send_push("@#{handle} quoted you:", op.raw_record)
  end

  def send_mention_notification(msg, op)
    handle = get_user_handle(msg.repo)

    send_push("@#{handle} mentioned you:", op.raw_record)
  end


  # likes

  def process_like(msg, op)
    data = op.raw_record

    if data['subject'] && data['subject']['uri']
      liked_uri = AtURI.new(data['subject']['uri'])

      if liked_uri.did == @user_did
        case liked_uri.collection
        when 'app.bsky.feed.post'
          send_post_like_notification(msg, liked_uri)
        when 'app.bsky.feed.generator'
          send_feed_like_notification(msg, liked_uri)
        end
      end
    end
  end

  def send_post_like_notification(msg, uri)
    handle = get_user_handle(msg.repo)
    post = get_record(uri)

    send_push("@#{handle} liked your post", post)
  end

  def send_feed_like_notification(msg, uri)
    handle = get_user_handle(msg.repo)
    feed = get_record(uri)

    send_push("@#{handle} liked your feed", feed)
  end


  # reposts

  def process_repost(msg, op)
    data = op.raw_record

    if data['subject'] && data['subject']['uri']
      reposted_uri = AtURI.new(data['subject']['uri'])

      if reposted_uri.did == @user_did && reposted_uri.collection == 'app.bsky.feed.post'
        send_repost_notification(msg, reposted_uri)
      end
    end
  end

  def send_repost_notification(msg, uri)
    handle = get_user_handle(msg.repo)
    post = get_record(uri)

    send_push("@#{handle} reposted your post", post)
  end


  # follows

  def process_follow(msg, op)
    if op.raw_record['subject'] == @user_did
      send_follow_notification(msg)
    end
  end

  def send_follow_notification(msg)
    handle = get_user_handle(msg.repo)

    send_push("@#{handle} followed you", msg.repo)
  end


  #
  # Note: in this example, we're calling the Bluesky AppView to get details about the person interacting with the user
  # and the post/feed that was liked/reposted etc. In a real app, you might run into rate limits if you do that,
  # because these requests will all be sent from the server's IP.
  #
  # So you might need to take a different route and send just the info that you have here in the push notification data
  # (the AT URI / DID) and fetch the details on the client side, e.g. in a Notification Service Extension on iOS.
  #

  def get_user_handle(did)
    url = "https://api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=#{did}"
    json = JSON.parse(URI.open(url).read)
    json['handle']
  end

  def get_record(uri)
    url = "https://api.bsky.app/xrpc/com.atproto.repo.getRecord?" +
          "repo=#{uri.did}&collection=#{uri.collection}&rkey=#{uri.rkey}"
    json = JSON.parse(URI.open(url).read)
    json['value']
  end

  def send_push(message, data = nil)
    # send the message to APNS/FCM here
    puts
    puts "[#{Time.now}] #{message} #{data&.inspect}"
  end
end

engine = NotificationEngine.new(monitored_did)

# close the connection cleanly on Ctrl+C
trap("SIGINT") { engine.disconnect }

engine.connect
