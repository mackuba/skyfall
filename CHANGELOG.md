## [0.6.0] - 2025-06-25

- significantly speeded up reading of events from the binary firehose (`Skyfall::Firehose`) - up to 4-5x faster than before
- removed the `Skyfall::Stream.new` constructor deprecated in 0.5.0

## [0.5.1] - 2025-05-18

- added support for the new `#sync` message type
- added `#unknown?` helper in `Skyfall::Firehose::Message` and `Skyfall::Jetstream::Message`, which returns true if the message type is `UnknownMessage`
- added `:bsky_verification` and `:bsky_actor_status` lexicon type and shortcode
- added one missing require

## [0.5.0] - 2024-11-15

Jetstream support! You can now connect to [Jetstream](https://github.com/bluesky-social/jetstream) sources using `Skyfall::Jetstream` (see readme).

This required some breaking changes in the existing API:

- `Skyfall::Stream` has been renamed to `Skyfall::Firehose`, `Skyfall::Stream` is now a base class of both `Firehose` and `Jetstream`; the existing `Skyfall::Stream` constructor works for now but will be removed soon
- `Skyfall::WebsocketMessage` and its subclasses have been separated into two parallel families under `Skyfall::Firehose` and `Skyfall::Jetstream`, with the base classes just named `Message`
- same thing happened with `Skyfall::Operation`
- `data_object` and `type_object` properties in `WebsocketMessage` are considered semi-private API now ("nodoc")

In most cases, you should only need to update the `Skyfall::Stream` class name in the constructor. If you've referenced message classes like `Skyfall::CommitMessage` directly, it's probably better to just check the `#type` property instead.

Also, small change to the user agent API: `Skyfall::Stream` now has an additional metod `version_string`, which will always return `Skyfall/0.x.y` - it's recommended to use that instead of `default_user_agent` to build your own user agent string that includes the library version. `default_user_agent` now passes through to `version_string`, but it could be changed in future to return something else.

## [0.4.1] - 2024-10-04

- performance fix - don't decode CAR sections which aren't needed, which is most of them; this cuts the amount of memory that GC has to free up by about one third, and should speed up processing by around ~10%

## [0.4.0] - 2024-09-23

- (re)added a "hearbeat" feature (removed earlier in 0.2.0) to fix the occasional issue when the websocket stops receiving data, but doesn't disconnect (not enabled by default, turn it on by setting `check_heartbeat` to true)
- added a way to set the user agent sent when connecting using the `user_agent` field (default is `"Skyfall/#{version}"`)
- added `app.bsky.feed.postgate` record type

## [0.3.1] - 2024-06-28

- added `app.bsky.graph.starterpack` and `chat.bsky.actor.declaration` record types
- added `#account` event type (`AccountMessage`)
- added `handle` field to `IdentityMessage`
- fixed param validation on `Stream` initialization
- reverted the change that added Ruby stdlib dependencies explicitly to the gemspec, since this causes more problems than it's worth - only `base64` is left there, since it's the one now required to be listed

## [0.3.0] - 2024-03-21

- added support for labeller firehose, served by labeller services at the `com.atproto.label.subscribeLabels` endpoint (aliased as `:subscribe_labels`)
- the `#labels` messages from the labeller firehose are parsed into a `LabelsMessage`, which includes a `labels` array of `Label` objects
- `Stream` callbacks can now also be assigned via setters, e.g. `stream.on_message = proc { ... }`
- added default error handler to `Stream` which logs the error to `$stdout` - set `stream.on_error = nil` to disable
- added Ruby stdlib dependencies explicitly to the gemspec - fixes a warning in Ruby 3.3 when requiring `base64`, which will be extracted as an optional gem in 3.4

## [0.2.5] - 2024-03-14

- added `:bsky_labeler` record type symbol & collection constant

## [0.2.4] - 2024-02-27

- added support for `#identity` message type
- added `Operation#did` as an alias of `#repo`
- added `Stream#reconnect` method which forces the websocket to reconnect
- added some validation for the `cursor` parameter in `Stream` initializer
- the `server` parameter in `Stream` initializer can be a full URL with scheme, which lets you connect to e.g. `ws://localhost` (since by default, `wss://` is used)
- tweaked `#inspect` output of `Stream` and `Operation`

## [0.2.3] - 2023-09-28

- fixed encoding of image CIDs again (they should be wrapped in a `$link` object)
- binary strings are now correctly returned as `$bytes` objects
- added `list`, `listblock` and `threadgate` to record type symbols and collection constants

## [0.2.2] - 2023-09-06

- fixed image CIDs returned in the record JSON as CBOR tag objects (they are now returned decoded to the string form)

## [0.2.1] - 2023-08-19

- optimized `WebsocketMessage` parsing performance - lazy parsing of most properties (message decoding should be over 50% faster on average)
- added separate subclasses of `WebsocketMessage` for different message types
- added support for `#handle`, `#info` and `#tombstone` message types
- `UnknownMessage` is returned for unrecognized message types

## [0.2.0] - 2023-07-24

- switched the websocket library from `websocket-client-simple` to `faye-websocket`, which should make event parsing up to ~30× faster (!)
- added `auto_reconnect` property to `Stream` (on by default) - if true, it will try to reconnect with an exponential backoff when the websocket disconnects, until you call `Stream#disconnect`

Note:

- calling `sleep` is no longer needed after connecting - call `connect` on a new thread instead to get previously default behavior of running the event loop asynchronously
- the disconnect event no longer passes an error object in the argument
- there is currently no "heartbeat" feature as in 0.1.x that checks for a stuck connection - but it doesn't seem to be needed

## [0.1.3] - 2023-07-04

- allow passing a previously saved cursor to websocket to replay any missed events
- the cursor is also kept in memory and automatically used when reconnecting
- added "connecting" callback with url as argument
- fixed connecting to websocket when endpoint is given as a string
- improved error handling during parsing

## [0.1.2] - 2023-06-15

- added rkey property for Operation

## [0.1.1] - 2023-06-13

- added heartbeat thread to restart websocket if it stops responding

## [0.1.0] - 2023-06-01

- connecting to the firehose websocket

## [0.0.1] - 2023-05-31

Initial release:

- parsing CBOR objects from a websocket message
- parsing CIDs, CAR archives and operation details from the objects
