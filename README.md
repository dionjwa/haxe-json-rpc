[haxe]: http://http://haxe.org
[nodejs]:http://nodejs.org/
[jsonrpc]:http://www.jsonrpc.org/specification

# [JSON-RPC][jsonrpc] remoting library for [Haxe][haxe] [![Build Status](https://travis-ci.org/dionjwa/haxe-json-rpc.svg?branch=master)](https://travis-ci.org/dionjwa/haxe-json-rpc)

This library aims to take the pain away from JSON-RPC calls. It is not heavily tied to JSON as the transport protocol, for instance Google Protobufs could be used if there was demand.

The [Haxe][haxe] language has several features that greatly simplify creating compile-time-checked RPC boilerplate code, as shown in the examples.

## Examples



## Installation

Add this to your hxml file (and install with `haxelib install json-rpc`):

	-lib json-rpc


## Limitations

 - Currently Node.js is the only server platform supported. Others can easily be added (pull requests welcome).
 - JSON-RPC as the protocol. Protobufs would probably be more efficient, at the cost of transport readability (pull requests welcome).
 - Tied to the Haxe language. I would explore the possibility of releasing a JS npm package, however that would lose some of the best features.

RPC is remoting, basically encapsulating a method call in some protocol so it can be called on some remote server. The server may return a result.




This library allows you to make JSON-RPC remoting calls from your client to your server. The relevant client code is built via macros so you get type checking on the client without having to write any client code.

For now, Node.js is the only server platform supported but others would be easy to add. Clients can be anything that supports Http requests or Websockets.

The remoting calls can be done either with Http or Websockets.

## Tests

To run the tests:

	./test/runtests.sh

The tests also show various client/server/http/websocket combinations.