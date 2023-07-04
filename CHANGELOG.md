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
