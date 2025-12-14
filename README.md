# Skyfall

A Ruby gem for streaming data from the Bluesky/ATProto firehose 🦋

> [!NOTE]
> Part of ATProto Ruby SDK: [ruby.sdk.blue](https://ruby.sdk.blue)


## What does it do

Skyfall is a Ruby library for connecting to the *"[firehose](https://atproto.com/specs/event-stream)"* of the Bluesky social network, i.e. a websocket which streams all new posts and everything else happening on the Bluesky network in real time. The code connects to the websocket endpoint, decodes the messages which are encoded in some binary formats like DAG-CBOR, and returns the data as Ruby objects, which you can filter and save to some kind of database (e.g. in order to create a custom feed).

Since version 0.5, Skyfall also supports connecting to [Jetstream](https://github.com/bluesky-social/jetstream/) sources, which serve the same kind of stream, but as JSON messages instead of CBOR.


## Installation

From the command line:

    gem install skyfall

Or, add this to your `Gemfile`:

    gem 'skyfall', '~> 0.6'


## Usage

### Standard ATProto firehose

To connect to the firehose, start by creating a `Skyfall::Firehose` object, specifying the server hostname and endpoint name:

```rb
require 'skyfall'

sky = Skyfall::Firehose.new('bsky.network', :subscribe_repos)
```

The server name can be just a hostname, or a full URL with a `ws:` or `wss:` scheme, which is useful if you want to use a non-encrypted websocket connection, e.g. `"ws://localhost:8000"`. The endpoint can be either a full NSID string like `"com.atproto.sync.subscribeRepos"`, or one of the defined symbol shortcuts - you will almost always want to pass `:subscribe_repos` here.

Next, set up event listeners to handle incoming messages and get notified of errors. Here are all the available listeners (you will need at least either `on_message` or `on_raw_message`):

```rb
# this gives you a parsed message object, one of subclasses of Skyfall::Firehose::Message
sky.on_message { |msg| p msg }

# this gives you raw binary data as received from the websocket
sky.on_raw_message { |data| p data }

# lifecycle events
sky.on_connecting { |url| puts "Connecting to #{url}..." }
sky.on_connect { puts "Connected" }
sky.on_disconnect { puts "Disconnected" }
sky.on_reconnect { puts "Connection lost, trying to reconnect..." }
sky.on_timeout { puts "Connection stalled, triggering a reconnect..." }

# handling errors (there's a default error handler that does exactly this)
sky.on_error { |e| puts "ERROR: #{e}" }
```

You can also call these as setters accepting a `Proc` - e.g. to disable default error handling, you can do:

```rb
sky.on_error = nil
```

When you're ready, open the connection by calling `connect`:

```rb
sky.connect
```

The `#connect` method blocks until the connection is explicitly closed with `#disconnect` from an event or interrupt handler. Skyfall uses [EventMachine](https://github.com/eventmachine/eventmachine) under the hood, so in order to run some things in parallel, you can use e.g. `EM::PeriodicTimer`.


### Using a Jetstream source

Alternatively, you can connect to a [Jetstream](https://github.com/bluesky-social/jetstream/) server. Jetstream is a firehose proxy that lets you stream data as simple JSON instead, which uses much less bandwidth, and allows you to pick only a subset of events that you're interested in, e.g. only posts or only from specific accounts. (See the [configuration section](#jetstream-filters) for more info on Jetstream filtering.)

Jetstream connections are made using a `Skyfall::Jetstream` instance, which has more or less the same API as `Skyfall::Firehose`, so it should be possible to switch between those by just changing the line that creates the client instance:

```rb
sky = Skyfall::Jetstream.new('jetstream2.us-east.bsky.network')

sky.on_message { |msg| ... }
sky.on_error { |e| ... }
sky.on_connect { ... }
...

sky.connect
```

### Cursors

ATProto websocket endpoints implement a "*cursor*" feature to help you make sure that you don't miss anything if your connection is down for a bit (because of a network issue, server restart, deploy etc.). Each message includes a `seq` field, which is the sequence number of the event. You can keep track of the last seq you've seen, and when you reconnect, you pass that number as a cursor parameter - the server will then "replay" all events you might have missed since that last one. (The `bsky.network` Relay firehose currently has a buffer of about 72 hours, though that's not something required by specification.)

To use a cursor when connecting to the firehose, pass it as the third parameter to `Skyfall::Firehose`. You should then regularly save the `seq` of the last event to some permanent storage, and then load it from there when reconnecting.

A full-network firehose sends many hundreds of events per second, so depending on your use case, it might be enough if you save it every n events (e.g. every 100 or 1000) and on clean shutdown:

```rb
cursor = load_cursor

sky = Skyfall::Firehose.new('bsky.network', :subscribe_repos, cursor)
sky.on_message do |msg|
  save_cursor(msg.seq) if msg.seq % 1000 == 0
  process_message(msg)
end
```

Jetstream has a similar mechanism, except the cursor is the event's timestamp in Unix time microseconds instead of just a number incrementing by 1. For `Skyfall::Jetstream`, pass the cursor as a key in an options hash:

```rb
cursor = load_cursor

sky = Skyfall::Jetstream.new('jetstream2.us-east.bsky.network', { cursor: cursor })
sky.on_message do |msg|
  save_cursor(msg.seq)
  process_message(msg)
end
```


### Processing messages

Each message passed to `on_message` is an instance of a subclass of either `Skyfall::Firehose::Message` or `Skyfall::Jetstream::Message`, depending on the selected source. The supported message types are:

- `CommitMessage` (`#commit`) - represents a change in a user's repo; most messages are of this type
- `IdentityMessage` (`#identity`) - notifies about a change in user's DID document, e.g. a handle change or a migration to a new PDS
- `AccountMessage` (`#account`) - notifies about a change of an account's status (de/activation, suspension, deletion)
- `HandleMessage` (`#handle` - deprecated) - when a different handle is assigned to a user's DID
- `TombstoneMessage` (`#tombstone` - deprecated) - when an account is deleted
- `LabelsMessage` (`#labels`) - only used in `subscribe_labels` endpoint
- `InfoMessage` (`#info`) - a protocol error message, e.g. about an invalid cursor parameter
- `UnknownMessage` is used for other unrecognized message types

`#handle` and `#tombstone` events are considered deprecated, replaced by `#identity` and `#account` respectively. They are still being emitted at the moment (in parallel with the newer event types), but they might stop being sent at any moment, so it's recommended that you don't rely on those.

`Skyfall::Firehose::Message` and `Skyfall::Jetstream::Message` variants of message classes should have more or less the same interface, except when a given field is not included in one of the formats.

All message objects have the following shared properties:

- `type` (symbol) - the message type identifier, e.g. `:commit`
- `seq` (integer) - a sequential index of the message; Jetstream messages instead have a `time_us` value, which is a Unix timestamp in microseconds (also aliased as `seq` for compatibility)
- `repo` or `did` (string) - DID of the repository (user account)
- `time` (Time) - timestamp of the described action

All properties except `type` may be nil for some message types that aren't related to a specific user, like `#info`.

Commit messages additionally have:

- `commit` - CID of the commit
- `operations` - list of operations (usually one)

Handle and Identity messages additionally have:

- `handle` - the new handle assigned to the DID

Account messages additionally have:

- `active?` - whether the account is active, or inactive for any reason
- `status` - if not active, shows the status of the account (`:deactivated`, `:deleted`, `:takendown`)

Info messages additionally have:

- `name` - identifier of the message/error
- `message` - a human-readable description


### Commit operations

Operations are objects of type `Skyfall::Firehose::Operation` or `Skyfall::Jetstream::Operation` and have such properties:

- `repo` or `did` (string) - DID of the repository (user account)
- `collection` (string) - name of the relevant collection in the repository, e.g. `app.bsky.feed.post` for posts
- `type` (symbol) - short name of the collection, e.g. `:bsky_post`
- `rkey` (string) - identifier of a record in a collection
- `path` (string) - the path part of the at:// URI - collection name + ID (rkey) of the item
- `uri` (string) - the complete at:// URI
- `action` (symbol) - `:create`, `:update` or `:delete`
- `cid` (CID) - CID of the operation/record (`nil` for delete operations)

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


### Note on custom lexicons

Note that the `Operation` objects have two properties that tell you the kind of record they're about: `#collection`, which is a string containing the official name of the collection/lexicon, e.g. `"app.bsky.feed.post"`; and `#type`, which is a symbol meant to save you some typing, e.g. `:bsky_post`.

When Skyfall receives a message about a record type that's not on the list, whether in the `app.bsky` namespace or not, the operation `type` will be `:unknown`, while the `collection` will be the original string. So if an app like e.g. "Skygram" appears with a `zz.skygram.*` namespace that lets you share photos on ATProto, the operations will have a type `:unknown` and collection names like `zz.skygram.feed.photo`, and you can check the `collection` field for record types known to you and process them in some appropriate way, even if Skyfall doesn't recognize the record type.

Do not however check if such operations have a `type` equal to `:unknown` first - just ignore the type and only check the `collection` string. The reason is that some next version of Skyfall might start recognizing those records and add a new `type` value for them like e.g. `:skygram_photo`, and then they won't match your condition anymore.


## Reconnection logic

In a perfect world, the websocket would never disconnect until you disconnect it, but unfortunately we don't live in a perfect world. The socket sometimes disconnects or stops responding, and Skyfall has some built-in protections to make sure it can operate without much oversight.


### Broken connections

If the connection is randomly closed for some reason, Skyfall will by default try to reconnect automatically. If the reconnection fails (e.g. because the network is down), it will wait with an [exponential backoff](https://en.wikipedia.org/wiki/Exponential_backoff) up to 5 minute intervals and keep retrying forever until it connects again. The `on_reconnect` callback is triggered when the connection is closed (before the wait delay). This mechanism should generally solve most of the problem.

The auto reconnecting feature is enabled by default, but you can turn it off by setting `auto_reconnect` to `false`.

### Stalled connections & heartbeat

Occasionally, especially during times of very heavy traffic, the websocket can get into a stuck state where it stops receiving any data, but doesn't disconnect and just hangs like this forever. To work around this, there is a "heartbeat" feature which starts a background timer, which periodically checks how much time has passed since the last received event, and if the time exceeds a set limit, it manually disconnects and reconnects the stream.

This feature is not enabled by default, because there are some firehoses which will not be sending events often, possibly only once in a while – e.g. labellers and independent PDS firehoses – and in this case we don't want any heartbeat since it will be completely normal not to have any events for a long time. It's not really possible to detect easily if we're connecting to a full network relay or one of those, so in order to avoid false alarms, you need to enable this manually using the `check_heartbeat` property.

You can also change the `heartbeat_interval`, i.e. how often the timer is triggered (default: 10s), and the `heartbeat_timeout`, i.e. the amount of time passed without events needed to cause a reconnect (default: 5 min):

```rb
sky.check_heartbeat = true
sky.heartbeat_interval = 5
sky.heartbeat_timeout = 120
```

### Cursors when reconnecting

Skyfall keeps track of the last event's `seq` internally in the `cursor` property, so if the client reconnects for whatever reason, it will automatically use the latest cursor in the URL.

> [!NOTE]
> This only happens if you use the `on_message` callback and not `on_raw_message`, since the event is not parsed from binary data into a `Message` object if you use `on_raw_message`, so Skyfall won't have access to the `seq` field then.


## Streaming from labellers

Apart from `subscribe_repos`, there is a second endpoint `subscribe_labels`, which is used to stream labels from [labellers](https://atproto.com/specs/label) (ATProto moderation services). This endpoint only sends `#labels` events (and possibly `#info`).

To connect to a labeller, pass `:subscribe_labels` as the endpoint name to `Skyfall::Firehose`. The `on_message` callback will get called with `Skyfall::Firehose::LabelsMessage` events, each of which includes one or more labels as `Skyfall::Label`:

```rb
cursor = load_cursor(service)
sky = Skyfall::Firehose.new(service, :subscribe_labels, cursor)
sky.on_message do |msg|
  if msg.type == :labels
    msg.labels.each do |l|
      puts "[#{l.created_at}] #{l.subject} => #{l.value}"
    end
  end
end
```

See [ATProto label docs](https://atproto.com/specs/label) for info on what fields are included with each label - `Skyfall::Label` includes properties with these original names, and also more friendly aliases for each (e.g. `value` instead of `val`).


## Other configuration

### User agent

Skyfall sends a user agent header when making a connection. This is set by default to `"Skyfall/0.x.y"`, but it's recommended that you override it using the `user_agent` field to something that identifies your app and its author – this will let the owner of the server you're connecting to know who to contact in case the client is causing some problems.

You can also append your user agent info to the default value like this:

```rb
sky.user_agent = "NewsBot (@news.bot) #{sky.version_string}"
```

### Jetstream filters

Jetstream allows you to specify [filters](https://github.com/bluesky-social/jetstream?tab=readme-ov-file#consuming-jetstream) of collection types and/or tracked DIDs when you connect, so it will send you only the events you're interested in. You can e.g. ask only for posts and ignore likes, or only profile events and ignore everything else, or only listen for posts from a few specific accounts.

To use these filters, pass the "wantedCollections" and/or "wantedDids" parameters in the options hash when initializing `Skyfall::Jetstream`. You can use the original JavaScript param names, or a more Ruby-like snake_case form:

```rb
sky = Skyfall::Jetstream.new('jetstream2.us-east.bsky.network', {
  wanted_collections: 'app.bsky.feed.post',
  wanted_dids: @dids
})
```

For collections, you can also use the symbol codes used in `Operation#type`, e.g. `:bsky_post`:

```rb
sky = Skyfall::Jetstream.new('jetstream2.us-east.bsky.network', {
  wanted_collections: [:bsky_post]
})
```

See [Jetstream docs](https://github.com/bluesky-social/jetstream?tab=readme-ov-file#consuming-jetstream) for more info on available filters.

> [!NOTE]
> The `compress` and `requireHello` options (and zstd compression) are not available at the moment. Also the "subscriber sourced messages" aren't implemented yet.


## Credits

Copyright © 2025 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
