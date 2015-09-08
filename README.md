[![Build Status](https://travis-ci.org/dionjwa/haxe-json-rpc.svg?branch=v0.0.11)](https://travis-ci.org/dionjwa/haxe-json-rpc)

[haxe]: http://http://haxe.org
[nodejs]:http://nodejs.org/
[jsonrpc]:http://www.jsonrpc.org/specification

# [JSON-RPC][jsonrpc] remoting library for [Haxe][haxe]

This library allows you to make JSON-RPC remoting calls from your client to your server. The relevant client code is built via macros so you get type checking on the client without having to write any client code.

For now, Node.js is the only server platform supported but others would be easy to add. Clients can be anything that supports Http requests or Websockets.

The remoting calls can be done either with Http or Websockets.

## Tests

To run the tests:

	./test/runtests.sh

The tests also show various client/server/http/websocket combinations.