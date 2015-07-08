[haxe]: http://http://haxe.org
[nodejs]:http://nodejs.org/

# Asynchronous remoting classes for [Haxe][haxe]

This package consists of:

2. Macros to build async client proxy remoting classes from interfaces or the server remoting class.  All server classes are excluded from the client.
3. Flash <-> JS asynchronous remoting connection (ExternalAsyncConnection)
4. Websocket wrappers for passing both JSON and Haxe serialized objects between a websocket client and server (Node.js)

See the demo for a working example.

## Installation/compilation

To build the demos:

1. [Install node.js][nodejs].

To run the remoting demo:

- In one terminal window run the server:

	node deploy/remoting-server/server.js

- In another terminal window, run the client:

	node deploy/remoting-server/client.js

In the client window, type a number and then enter.  The server sends back a processed result.


## Usage (building your own remoting classes)

Assume you have a remoting class on the server:

	package foo;

	@:build(transition9.remoting.Macros.remotingClass())
	class FooRemote
	{
		@remote
		public function getTheFoo(fooId :String, cb :String->Void) :Void
		{
			cb("someFoo");
		}
	}

On the client, you can construct a fully typed proxy async remoting class with:

	//Create the remoting Html connection
	var conn = haxe.remoting.HttpAsyncConnection.urlConnect("http://localhost:8000");

	//Build and instantiate the proxy class with macros.
	//The full path to the server class is given as the first argument, but it is NOT compiled into the client by default
	var fooProxy = transition9.remoting.Macros.buildAndInstantiateRemoteProxyClass(foo.FooRemote, conn);

	//You can use code completion here
	fooProxy.getTheFoo("fooId", function (foo :String) :Void {
		trace("successfully got the foo=" + foo);
	});

Instead of a remoting class, you can also build the proxy from an interface:

	interface FooRemote
	{
		@remote
		public function getTheFoo(fooId :String, cb :String->Void) :Void;
	}

You can also create an interface from the remoting class:

	@:build(transition9.remoting.Macros.addRemoteMethodsToInterfaceFrom(foo.FooRemote))
	interface FooService {}

Then the client proxy class is declared with

	@:build(transition9.remoting.Macros.buildAsyncProxyClassFromInterface(FooRemote))
	//Or @:build(transition9.remoting.Macros.buildAsyncProxyClassFromInterface("foo.FooRemote"))
	class FooProxy implements IRemotingService {}:

In the future, you will be able to build and instantiate the interface derived proxy the same as the class derived proxy above.

## Running the unit tests

There are two unit tests:

	./test/runtests.sh

## Coming soon:

Websockets.  Relies on the flambe lib.

To run the websocket demo:

- In one terminal window run the server:

	node deploy/websocket-server/server.js

- In another terminal window, run the first client:

	node deploy/websocket-server/client.js

- Finally in a third terminal window, run the second client:

	node deploy/websocket-server/client.js
