# Skyfall

🌤 A Ruby gem for streaming data from the Bluesky/AtProto firehose 🦋


## What does it do

Skyfall is a Ruby library for connecting to the *"firehose"* of the Bluesky social network, i.e. a websocket which
streams all new posts and everything else happening on the Bluesky network in real time. The code connects to the
websocket endpoint, decodes the messages which are encoded in some binary formats like DAG-CBOR, and returns the data as Ruby objects, which you can filter and save to some kind of database (e.g. in order to create a custom feed).


## Installation

    gem install skyfall


## Usage

Start a connection to the firehose by creating a `Skyfall::Stream` object, passing the server hostname and endpoint name:

```rb
require 'skyfall'

sky = Skyfall::Stream.new('bsky.social', :subscribe_repos)
```

Add event listeners to handle incoming messages and get notified of errors:

```rb
sky.on_connect { puts "Connected" }
sky.on_disconnect { puts "Disconnected" }

sky.on_message { |m| p m }
sky.on_error { |e| puts "ERROR: #{e}" }
```

When you're ready, open the connection by calling `connect`:

```rb
sky.connect
```


### Processing messages

Each message passed to `on_message` is an instance of the `WebsocketMessage` class and has such properties:

- `type` (symbol) - usually `:commit`
- `seq` (sequential number)
- `time` (Time)
- `repo` (string) - DID of the repository (user account)
- `commit` - CID of the commit
- `prev` - CID of the previous commit in that repo
- `operations` - list of operations (usually one)

Operations are objects of type `Operation` and have such properties:

- `repo` (string) - DID of the repository (user account)
- `collection` (string) - name of the relevant collection in the repository, e.g. `app.bsky.feed.post` for posts
- `path` (string) - the path part of the at:// URI - collection name + ID (rkey) of the item
- `action` (symbol) - `:create`, `:update` or `:delete`
- `uri` (string) - the at:// URI
- `type` (symbol) - short name of the collection, e.g. `:bsky_post`
- `cid` - CID of the operation/record (`nil` for delete operations)

Create and update operations will also have an attached record (JSON object) with details of the post, like etc. The record data is currently available as a Ruby hash via `raw_record` property (custom types will be added in a later version).

So for example, in order to filter only "create post" operations and print their details, you can do something like this:

```rb
sky.on_message do |m|
  next if m.type != :commit

  m.operations.each do |op|
    next unless op.action == :create && op.type == :bsky_post

    puts "#{op.repo}:"
    puts op.raw_record['text']
    puts
  end
end
```

See complete example in [example/firehose.rb](https://github.com/mackuba/skyfall/blob/master/example/firehose.rb).


## Credits

Copyright © 2023 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/mackuba.eu)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
