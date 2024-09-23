# Skyfall

A Ruby gem for streaming data from the Bluesky/AtProto firehose 🦋

> [!NOTE]
> ATProto Ruby gems collection: [skyfall](https://github.com/mackuba/skyfall) | [blue_factory](https://github.com/mackuba/blue_factory) | [minisky](https://github.com/mackuba/minisky) | [didkit](https://github.com/mackuba/didkit)


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

sky = Skyfall::Stream.new('bsky.network', :subscribe_repos)
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

Each message passed to `on_message` is an instance of a subclass of `WebsocketMessage`, depending on the message type. The supported message types are:

- `CommitMessage` (`#commit`) - represents a change in a user's repo; most messages are of this type
- `HandleMessage` (`#handle`) - when a different handle is assigned to a user's DID
- `TombstoneMessage` (`#tombstone`) - when an account is deleted
- `InfoMessage` (`#info`) - a protocol error message, e.g. about an invalid cursor parameter
- `UnknownMessage` is used for other unrecognized message types

All message objects have the following properties:

- `type` (symbol) - the message type identifier, e.g. `:commit`
- `seq` (integer) - a sequential index of the message
- `repo` or `did` (string) - DID of the repository (user account)
- `time` (Time) - timestamp of the described action

All properties except `type` may be nil for some message types that aren't related to a specific user, like `#info`.

Commit messages additionally have:

- `commit` - CID of the commit
- `prev` - CID of the previous commit in that repo
- `operations` - list of operations (usually one)

Handle messages additionally have:

- `handle` - the new handle assigned to the DID

Info messages additionally have:

- `name` - identifier of the message/error
- `message` - a human-readable description


### Commit operations

Operations are objects of type `Operation` and have such properties:

- `repo` or `did` (string) - DID of the repository (user account)
- `collection` (string) - name of the relevant collection in the repository, e.g. `app.bsky.feed.post` for posts
- `type` (symbol) - short name of the collection, e.g. `:bsky_post`
- `rkey` (string) - identifier of a record in a collection
- `path` (string) - the path part of the at:// URI - collection name + ID (rkey) of the item
- `uri` (string) - the complete at:// URI
- `action` (symbol) - `:create`, `:update` or `:delete`
- `cid` - CID of the operation/record (`nil` for delete operations)

Create and update operations will also have an attached record (JSON object) with details of the post, like etc. The record data is currently available as a Ruby hash via `raw_record` property (custom types will be added in future).

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

For more examples, see the [example](https://github.com/mackuba/skyfall/blob/master/example) folder or the [bluesky-feeds-rb](https://github.com/mackuba/bluesky-feeds-rb/blob/master/app/firehose_stream.rb) project, which implements a feed generator service.


### Custom lexicons

A note on custom lexicons: the `Skyfall::Operation` objects have two properties that tell you the kind of record they're about: `#collection`, which is a string containing the official name of the collection/lexicon, e.g. `"app.bsky.feed.post"`; and `#type`, which is a symbol meant to save you some typing, e.g. `:bsky_post`.

When Skyfall receives a message about a record type that's not on the list, whether in the `app.bsky` namespace or not, the operation `type` will be `:unknown`, while the `collection` will be the original string. So if an app like e.g. "Skygram" appears with a `zz.skygram.*` namespace that lets you share photos on ATProto, the operations will have a type `:unknown` and collection names like `zz.skygram.feed.photo`, and you can check the `collection` field for record types known to you and process them in some appropriate way, even if Skyfall doesn't recognize the record type.

Do not however check if such operations have a `type` equal to `:unknown` first - just ignore the type and only check the `collection` string. The reason is that some next version of Skyfall might start recognizing those records and add a new `type` value for them like e.g. `:skygram_photo`, and then they won't match your condition anymore.


## Configuration

### User agent

`Skyfall::Stream` sends a user agent header when making a connection. This is set by default to `"Skyfall/0.x.y"`, but it's recommended that you override it using the `user_agent` field to something that identifies your app and its author – this will let the owner of the server you're connecting to know who to contact in case the client is causing some problems.

You can also append your user agent info to the default value like this:

```rb
sky.user_agent = "NewsBot (@news.bot) #{sky.default_user_agent}"
```

### Heartbeat and reconnecting

Occasionally, especially during times of very heavy traffic, the websocket can get into a stuck state where it stops receiving any data, but doesn't disconnect and just hangs like this forever. To work around this, there is a "heartbeat" feature which starts a background timer, which periodically checks how much time has passed since the last received event, and if the time exceeds a set limit, it manually disconnects and reconnects the stream.

The option is not enabled by default, because there are some firehoses which will not be sending events often, possibly only once in a while – e.g. labellers and independent PDS firehoses – and in this case we don't want any heartbeat since it will be completely normal not to have any events for a long time. It's not really possible to detect easily if we're connecting to a full network relay or one of those, so in order to avoid false alarms, you need to enable this manually using the `check_heartbeat` property.

You can also change the `heartbeat_interval`, i.e. how often the timer is triggered (default: 10s), and the `heartbeat_timeout`, i.e. the amount of time passed without events when it reconnects (default: 5 min):

```rb
sky.check_heartbeat = true
sky.heartbeat_interval = 5
sky.heartbeat_timeout = 120
```


## Credits

Copyright © 2024 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/mackuba.eu)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
