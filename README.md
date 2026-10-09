# Skyfall

[![Gem Version](https://badge.fury.io/rb/skyfall.svg?icon=si%3Arubygems&icon_color=%23ff6251)](https://rubygems.org/gems/skyfall) [![YARD Docs](http://img.shields.io/badge/yard-docs-blue.svg)](https://rubydoc.info/gems/skyfall)

A Ruby gem for streaming data from the Bluesky/ATProto firehose 🦋

> [!NOTE]
> Part of ATProto Ruby SDK: [ruby.sdk.blue](https://ruby.sdk.blue)


## What does it do

Skyfall is a Ruby library for connecting to the *"[firehose](https://atproto.com/specs/event-stream)"* of the Bluesky social network, i.e. a websocket which streams all new posts and everything else happening on the Bluesky network in real time. The code connects to the websocket endpoint, decodes the messages which are encoded in some binary formats like DAG-CBOR, and returns the data as Ruby objects, which you can filter and save to some kind of database (e.g. in order to create a custom feed).

Since version 0.5, Skyfall also supports connecting to [Jetstream](https://github.com/bluesky-social/jetstream/) sources, which serve the same kind of stream, but as JSON messages instead of CBOR. Jetstream v2 API is supported since version 0.8.


## Installation

To use Skyfall, you need a reasonably new version of Ruby – it should run on Ruby 2.6 and above, although it's recommended to use a version that's still getting maintainance updates, i.e. currently 3.3+. A compatible version should be preinstalled on macOS Big Sur and above and on many Linux systems. Otherwise, you can install one using tools such as [RVM](https://rvm.io), [asdf](https://asdf-vm.com), [ruby-install](https://github.com/postmodern/ruby-install) or [ruby-build](https://github.com/rbenv/ruby-build), or `rpm` or `apt-get` on Linux (see more installation options on [ruby-lang.org](https://www.ruby-lang.org/en/downloads/)).

To install the gem, run the command:

    [sudo] gem install skyfall

Or add this to your app's `Gemfile`:

    gem 'skyfall', '~> 0.8'


## Usage

### Standard ATProto firehose

To connect to the firehose, start by creating a `Skyfall::Firehose` object, specifying the server hostname and optionally an endpoint name:

```rb
require 'skyfall'

sky = Skyfall::Firehose.new('bsky.network', :subscribe_repos)

# or (:subscribe_repos is the default)
sky = Skyfall::Firehose.new('bsky.network')
```

The server name can be just a hostname, or a full URL with a `ws:` or `wss:` scheme, which is useful if you want to use a non-encrypted websocket connection, e.g. `"ws://localhost:8000"`. The endpoint can be either a full NSID string like `"com.atproto.sync.subscribeRepos"`, or one of the defined symbol shortcuts – you will almost always want to use `:subscribe_repos`.

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

You can also call these as setters accepting a `Proc` – e.g. to disable default error handling, you can do:

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

There are two different versions of Jetstream:

* the [original Jetstream](https://github.com/bluesky-social/jetstream-legacy/) (v1); most community-run [Jetstream instances](https://pulsar.feeds.blue) out there are running this version. Use the `Skyfall::Jetstream` class to connect to those.
* the [Jetstream v2](https://github.com/bluesky-social/jetstream/), which uses a slightly different JSON structure, keeps a complete historical archive, and has APIs for backfilling historical data (not supported in Skyfall yet). Use the `Skyfall::JetstreamV2` class to connect to v2 instances, although `Skyfall::Jetstream` can also be used to connect to the v1 compatibility API. `Skyfall::JetstreamV2` will not work with v1 instances.

Both `Skyfall::Jetstream` and `Skyfall::JetstreamV2` have intentionally the same API as `Skyfall::Firehose` as much as possible:

```rb
sky = Skyfall::Jetstream.new('frankfurt.firehose.stream')
sky2 = Skyfall::JetstreamV2.new('jetstream.us-east.bsky.network')

sky.on_message { |msg| ... }
sky.on_error { |e| ... }
sky.on_connect { ... }
...

sky.connect
```

### Cursors

ATProto websocket endpoints implement a "*cursor*" feature to help you make sure that you don't miss anything if your connection is down for a bit (because of a network issue, server restart, deploy etc.). Each message includes a `seq` field, which is the sequence number of the event. You can keep track of the last seq you've seen, and when you reconnect, you pass that number as a cursor parameter – the server will then "replay" all events you might have missed since that last one. (Different relay and Jetstream servers have differently sized replay buffers depending on configuration, usually between 24 and 72 hours.)

To use a cursor when connecting to the CBOR firehose, pass it as the third (or second) parameter to `Skyfall::Firehose`. You should then regularly save the `seq` of the last event (also aliased as `cursor`) to some permanent storage, and then load it from there when reconnecting.

A full-network firehose sends many hundreds of events per second, so depending on your use case, it might be enough if you save it every n events (e.g. every 100 or 1000) and on clean shutdown:

```rb
cursor = load_cursor

sky = Skyfall::Firehose.new('bsky.network', cursor)

sky.on_message do |msg|
  save_cursor(msg.cursor) if msg.cursor % 1000 == 0
  process_message(msg)
end
```

Jetstream has a similar mechanism, except the cursor works a bit differently depending on the Jetstream client and server version:

* v1 servers include a `time_us` field, which is the Unix timestamp of the event in microseconds, which acts as a cursor. For a v1 service, `seq` and `cursor` methods in `Skyfall::Jetstream::Message` will both return this value.
* v2 servers include a `seq` field with a sequential number cursor like in the CBOR firehose. `seq` / `cursor` methods in `Skyfall::JetstreamV2::Message` return this sequential cursor value. For symmetry with `Skyfall::Jetstream::Message`, a `time_us` method is also provided here that returns the event time in microseconds.
* when a v1 client (`Skyfall::Jetstream`) connects to a v2 service, it uses a special v1 compatibility API there. In that API, the responses have a v1 JSON shape, *except* they also include a sequential cursor in a `cursor` field. In that case, `Skyfall::Jetstream::Message` will have a `time_us` with the timestamp field, but `seq` & `cursor` return that sequential cursor.
* in both APIs on a v2 service, either the sequential or the timestamp cursor can be passed when reconnecting.
* to simplify, in any combination of client and server API you can record & reuse the value returned from `message.cursor` and it should be accepted by the same server. You might need to take some more care with the cursor when switching between different instances.

Here's a table showing all combinations:

|                     | `seq`             | `cursor`          | `time_us`        | `time`               |
|---------------------|-------------------|-------------------|------------------|----------------------|
| CBOR firehose       | seq cursor        | seq cursor        | `time` in µs     | built from `time`    |
| Jetstream v1        | timestamp cursor  | timestamp cursor  | timestamp cursor | built from `time_us` |
| v1 compat API on v2 | seq cursor        | seq cursor        | timestamp cursor | built from `time_us` |
| Jetstream v2        | seq cursor        | seq cursor        | `time` in µs     | built from `time`    |

For any cursor and Jetstream client version, you pass the cursor as a key in an options hash:

```rb
cursor = load_cursor

sky = Skyfall::Jetstream.new('london.firehose.stream', { cursor: cursor })

sky.on_message do |msg|
  save_cursor(msg.cursor) unless msg.cursor.nil?
  process_message(msg)
end
```


### Processing messages

Each message passed to `on_message` is an instance of a subclass of `Skyfall::Firehose::Message`, `Skyfall::Jetstream::Message`, or `Skyfall::JetstreamV2::Message`, depending on the selected source. For the CBOR firehose, the supported message types are:

- `CommitMessage` (`#commit`) – represents a change in a user's repo; most messages are of this type
- `IdentityMessage` (`#identity`) – notifies about a change in user's DID document, e.g. a handle change or a migration to a new PDS
- `AccountMessage` (`#account`) – notifies about a change of an account's status (de/activation, suspension, deletion)
- `SyncMessage` (`#sync`) – updates repository state, can be used to trigger account resynchronization
- `LabelsMessage` (`#labels`) – only used in `subscribe_labels` endpoint
- `InfoMessage` (`#info`) – a protocol error message, e.g. about an invalid cursor parameter
- `UnknownMessage` is used for other unrecognized message types

`Skyfall::Jetstream` and `Skyfall::JetstreamV2` have their own message class families which mirror these and have more or less the same interface, except when a given field or message type is not included in one of the formats:

- Jetstream has: `AccountMessage`, `CommitMessage`, `IdentityMessage` and `UnknownMessage`
- JetstreamV2 has: `AccountMessage`, `CommitMessage`, `IdentityMessage`, `SyncMessage`, `InfoMessage` and `UnknownMessage`

All message objects have the following shared properties:

- `type` or `kind` (symbol) – the message type identifier, e.g. `:commit`
- `seq` or `cursor` (integer) – the cursor value to pass when reconnecting; either a sequential index of the message, or a Unix timestamp in microseconds for Jetstream v1 servers
- `repo` or `did` (string) – DID of the repository (user account)
- `time` (Time) – timestamp of the described action
- `time_us` (integer) – timestamp in Unix microseconds (for Jetstream v1/v2 can be used as a cursor)

All properties except `type` may be nil for some message types that aren't related to a specific user, like `#info`.

Commit messages additionally include (depending on the version):

- `commit` or `cid` – CID of the commit
- `operations` or `ops` – list of operations (usually one for CBOR, always one for Jetstream)
- `operation` or `op` – in Jetstream only
- `rev` – current revision identifier of the repo
- `since` – revision of the previous commit
- `blocks` – commit data as a parsed CAR archive

Identity messages additionally include:

- `handle` – the new handle assigned to the DID

Account messages additionally include:

- `active?` – whether the account is active, or inactive for any reason
- `status` – if not active, shows the status of the account (`:deactivated`, `:deleted`, `:takendown`)

Info messages additionally include:

- `name` – identifier of the message/error
- `message` – a human-readable description

See the [YARD API docs](https://rubydoc.info/gems/skyfall/) for more details on what specific message classes are available and what fields each one has.


### Commit operations

Operations are objects of type `Skyfall::Firehose::Operation` or `Skyfall::Jetstream::Operation` and have such properties:

- `repo` or `did` (string) – DID of the repository (user account)
- `collection` (string) – name of the relevant collection in the repository, e.g. `app.bsky.feed.post` for posts
- `type` (symbol) – short name of the collection, e.g. `:bsky_post`
- `rkey` (string) – identifier of a record in a collection
- `path` (string) – the path part of the at:// URI – collection name + ID (rkey) of the item
- `uri` (string) – the complete at:// URI
- `action` (symbol) – `:create`, `:update` or `:delete`
- `cid` (CID) – CID of the operation/record (`nil` for delete operations)

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

For more examples, see the [examples page](https://ruby.sdk.blue/examples/) on [ruby.sdk.blue](https://ruby.sdk.blue), or the [bluesky-feeds-rb](https://tangled.org/mackuba.eu/bluesky-feeds-rb/blob/master/app/firehose_stream.rb) project, which implements a feed generator service.


### Note on custom lexicons

Note that the `Operation` objects have two properties that tell you the kind of record they're about: `#collection`, which is a string containing the official name of the collection/lexicon, e.g. `"app.bsky.feed.post"`; and `#type`, which is a symbol meant to save you some typing, e.g. `:bsky_post`.

When Skyfall receives a message about a record type that's not on the list, whether in the `app.bsky` namespace or not, the operation `type` will be `:unknown`, while the `collection` will be the original string. So if an app like e.g. "Skygram" appears with a `zz.skygram.*` namespace that lets you share photos on ATProto, the operations will have a type `:unknown` and collection names like `zz.skygram.feed.photo`, and you can check the `collection` field for record types known to you and process them in some appropriate way, even if Skyfall doesn't recognize the record type.

Do not however check if such operations have a `type` equal to `:unknown` first – just ignore the type and only check the `collection` string. The reason is that some next version of Skyfall might start recognizing those records and add a new `type` value for them like e.g. `:skygram_photo`, and then they won't match your condition anymore.


## Reconnection logic

In a perfect world, the websocket would never disconnect until you disconnect it, but unfortunately we don't live in a perfect world. The socket sometimes disconnects or stops responding, and Skyfall has some built-in protections to make sure it can operate without much oversight. (This section applies to all three stream types.)


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

See [ATProto label docs](https://atproto.com/specs/label) for info on what fields are included with each label – `Skyfall::Label` includes properties with these original names, and also more friendly aliases for each (e.g. `value` instead of `val`).


## Other configuration

### User agent

Skyfall sends a user agent header when making a connection. This is set by default to `"Skyfall/0.x.y"`, but it's recommended that you override it using the `user_agent` field to something that identifies your app and its author – this will let the owner of the server you're connecting to know who to contact in case the client is causing some problems.

You can also append your user agent info to the default value like this:

```rb
sky.user_agent = "NewsBot (@news.bot) #{sky.version_string}"
```

### Jetstream filters

Jetstream allows you to specify [filters](https://bsky.network/docs/jetstream#filtering-ask-for-just-your-slice) of collection types and/or tracked DIDs when you connect, so it will send you only the events you're interested in. You can e.g. ask only for posts and ignore likes, or only profile events and ignore everything else, or only listen for posts from a few specific accounts.

To use these filters, pass the "wantedCollections" and/or "wantedDids" parameters in the options hash when initializing `Skyfall::Jetstream`. You can use the original JavaScript param names, or a more Ruby-like snake_case form, with a single value or an array:

```rb
sky = Skyfall::Jetstream.new('nyc.firehose.stream', {
  wanted_collections: 'app.bsky.feed.post',
  wanted_dids: @dids
})
```

For collections, you can also use the symbol codes used in `Operation#type`, e.g. `:bsky_post`:

```rb
sky = Skyfall::Jetstream.new('nyc.firehose.stream', {
  wanted_collections: [:bsky_post]
})
```

The parameters are named `collections` and `dids` respectively in the Jetstream v2 API, but you can use any variant in either of the client versions here.

Jetstream v2 additionally allows you to filter by event kinds. Pass one or more event types as the `kinds` option – note that `collections` can be combined with `kinds`, but only if `kinds` includes `commit`:

```rb
sky = Skyfall::JetstreamV2.new('jetstream.us-east.bsky.network', {
  collections: [:bsky_post, :bsky_like],
  kinds: [:commit, :identity]
})
```

See [Jetstream docs](https://bsky.network/docs/jetstream#filtering-ask-for-just-your-slice) for more info on available filters.

> [!NOTE]
> The `requireHello` option and "subscriber sourced messages" from the Jetstream v1 aren't currently supported (and probably won't be).


### Jetstream compression

Both Jetstream v1 and v2 support optional Zstd compression (off by default), using a pre-shared compression dictionary. For Jetstream v1 there is a single hardcoded dictionary, for v2 the currently used dictionary is fetched from the server before making a connection.

In both versions, enable compression by adding a `compress: true` option:

```rb
sky = Skyfall::Jetstream.new('nyc.firehose.stream', {
  wanted_collections: [:bsky_post],
  compress: true
})
```

The decompression and dictionary handling happens automatically. Note that if compression is enabled, `on_raw_message` callbacks will receive the original compressed message bytes; `on_message` receives a parsed `Message` object as before.


### Jetstream message size limit

Another Jetstream option is `maxMessageSizeBytes`, available in both v1 and v2, which sets a limit in bytes on how large events will be sent to the client; events larger than the limit are silently dropped.

Note: when compression is also enabled, the value is interpreted differently in Jetstream v1 and v2:

* Jetstream v1 uses the value as the max *compressed* event size
* Jetstream v2 servers, including the v1 compatibility API, use the value as the max *uncompressed* event size

Pass the limit as a number in bytes to `:maxMessageSizeBytes` or `:max_message_size_bytes` (0 will be interpreted as no limit):

```rb
sky = Skyfall::Jetstream.new('nyc.firehose.stream', { max_message_size_bytes: 1_000_000 })
```

## Available servers

Bluesky PBC currently runs these official firehose and Jetstream servers:

Relay:

- `bsky.network`

Jetstream v1:

- `jetstream1.us-west.bsky.network`, `jetstream2.us-west.bsky.network`
- `jetstream1.us-east.bsky.network`, `jetstream2.us-east.bsky.network`

Jetstream v2:

- `jetstream.us-west.bsky.network`
- `jetstream.us-east.bsky.network`

The ATProto developer community is running a number of independent relays and Jetstream instances, including:

- the [firehose.network](https://firehose.network) relays and [firehose.stream](https://firehose.stream) Jetstream servers run by [@sri.xyz](https://bsky.app/profile/did:plc:7gm5ejhut7kia2kzglqfew5b)
- the [Microcosm relays](https://www.microcosm.blue/#infra) run by [@bad-example.com](https://bsky.app/profile/did:plc:hdhoaan3xa3jiuq4fg4mefid)
- the [Blacksky](https://blackskyweb.xyz) and [Eurosky](https://eurosky.tech) infrastructure

I'm running a tool named [Pulsar](https://pulsar.feeds.blue) at [pulsar.feeds.blue](https://pulsar.feeds.blue) which lists all of those and more, and tracks their uptime and network coverage statistics.


## Other resources

- [YARD API documentation](https://rubydoc.info/gems/skyfall) at rubydoc.info
- [ruby.sdk.blue](https://ruby.sdk.blue)
- [Example scripts](https://ruby.sdk.blue/examples/)
- [bluesky-feeds-rb](https://tangled.org/mackuba.eu/bluesky-feeds-rb) – feed generator template project

## Credits

Copyright © 2026 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
