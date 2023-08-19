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
