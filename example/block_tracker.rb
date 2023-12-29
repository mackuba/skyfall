#!/usr/bin/env ruby

# Example: monitor the network for people blocking your account or adding you to mute lists.

# load skyfall from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'json'
require 'open-uri'
require 'skyfall'

$monitored_did = ARGV[0]

if $monitored_did.to_s.empty?
  puts "Usage: #{$PROGRAM_NAME} <monitored_did>"
  exit 1
elsif ARGV[0] !~ /^did:plc:[a-z0-9]{24}$/
  puts "Not a valid DID: #{$monitored_did}"
  exit 1
end

sky = Skyfall::Stream.new('bsky.network', :subscribe_repos)

sky.on_connect { puts "Connected, monitoring #{$monitored_did}" }
sky.on_disconnect { puts "Disconnected" }
sky.on_reconnect { puts "Reconnecting..." }
sky.on_error { |e| puts "ERROR: #{e}" }

sky.on_message do |msg|
  # we're only interested in repo commit messages
  next if msg.type != :commit

  msg.operations.each do |op|
    next if op.action != :create

    begin
      case op.type
      when :bsky_block
        process_block(msg, op)
      when :bsky_listitem
        process_list_item(msg, op)
      end
    rescue StandardError => e
      puts "Error: #{e}"
    end
  end
end

def process_block(msg, op)
  if op.raw_record['subject'] == $monitored_did
    owner_handle = get_user_handle(op.repo)
    puts "@#{owner_handle} has blocked you! (#{msg.time.getlocal})"
  end
end

def process_list_item(msg, op)
  if op.raw_record['subject'] == $monitored_did
    owner_handle = get_user_handle(op.repo)

    list_uri = op.raw_record['list']
    list_name = get_list_name(list_uri)

    puts "@#{owner_handle} has added you to list \"#{list_name}\" (#{msg.time.getlocal})"
  end
end

def get_user_handle(did)
  url = "https://plc.directory/#{did}"
  json = JSON.parse(URI.open(url).read)
  json['alsoKnownAs'][0].gsub('at://', '')
end

def get_list_name(list_uri)
  repo, type, rkey = list_uri.gsub('at://', '').split('/')
  url = "https://bsky.social/xrpc/com.atproto.repo.getRecord?repo=#{repo}&collection=#{type}&rkey=#{rkey}"

  json = JSON.parse(URI.open(url).read)
  json['value']['name']
end

# close the connection cleanly on Ctrl+C
trap("SIGINT") { sky.disconnect }

sky.connect
