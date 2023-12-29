#!/usr/bin/env ruby

# Example: print the date and text of every new post made on the network as they appear.

# load skyfall from a local folder - you normally won't need this
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'skyfall'

sky = Skyfall::Stream.new('bsky.network', :subscribe_repos)

sky.on_message do |msg|
  # we're only interested in repo commit messages
  next if msg.type != :commit

  msg.operations.each do |op|
    # ignore any operations other than "create post"
    next unless op.action == :create && op.type == :bsky_post

    puts "#{op.repo} • #{msg.time.getlocal}"
    puts op.raw_record['text']
    puts
  end
end

sky.on_connect { puts "Connected" }
sky.on_disconnect { puts "Disconnected" }
sky.on_reconnect { puts "Reconnecting..." }
sky.on_error { |e| puts "ERROR: #{e}" }

# close the connection cleanly on Ctrl+C
trap("SIGINT") { sky.disconnect }

sky.connect
