#!/usr/bin/env ruby

# Example: monitor new posts for mentions of one or more words or phrases (e.g. anyone mentioning your name or the name
# of your company, project etc.).

# load skyfall from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'json'
require 'open-uri'
require 'skyfall'

terms = ARGV.map(&:downcase)

if terms.empty?
  puts "Usage: #{$PROGRAM_NAME} <word_or_phrase> [<word_or_phrase>...]"
  exit 1
end

sky = Skyfall::Stream.new('bsky.network', :subscribe_repos)

sky.on_message do |msg|
  # we're only interested in repo commit messages
  next if msg.type != :commit

  msg.operations.each do |op|
    # ignore any operations other than "create post"
    next unless op.action == :create && op.type == :bsky_post

    text = op.raw_record['text'].to_s.downcase

    if terms.any? { |x| text.include?(x) }
      owner_handle = get_user_handle(op.repo)
      puts "\n#{msg.time.getlocal} @#{owner_handle}: #{op.raw_record['text']}"
    end
  end
end

def get_user_handle(did)
  url = "https://plc.directory/#{did}"
  json = JSON.parse(URI.open(url).read)
  json['alsoKnownAs'][0].gsub('at://', '')
end

sky.on_connect { puts "Connected" }
sky.on_disconnect { puts "Disconnected" }
sky.on_reconnect { puts "Reconnecting..." }
sky.on_error { |e| puts "ERROR: #{e}" }

# close the connection cleanly on Ctrl+C
trap("SIGINT") { sky.disconnect }

sky.connect
