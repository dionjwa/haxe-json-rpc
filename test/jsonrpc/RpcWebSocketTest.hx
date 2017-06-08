package jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.unit.async.PromiseTest;

import js.Node;
import js.node.Http;
// import js.node.http.*;
import js.npm.ws.WebSocket;
import js.npm.ws.WebSocketServer;


import promhx.Promise;
import promhx.Deferred;
import promhx.deferred.DeferredPromise;

import t9.js.jsonrpc.Routes;

import t9.remoting.jsonrpc.JsonRpcConnectionWebSocket;
import t9.remoting.jsonrpc.JsonRpcConnectionWebSocketServer;

class RpcWebSocketTest extends PromiseTest
{
	public function new() {}

	@Test
	public function testHttpWebsocketRpc () :Promise<Bool>
	{
		var deferred = new Deferred();
		var promise = deferred.promise();

		var port = 8082;

		//Server infrastructure
		var wss = new WebSocketServer({port:port});
		var serverContext = new t9.remoting.jsonrpc.Context();
		var service = new TestService1();
		serverContext.registerService(service);

		var handler = Routes.generateJsonRpcRequestHandler(serverContext);

		wss.on('connection', function connection(ws :WebSocket) {
			var sender = function(rpcResponse :ResponseDef) {
				ws.send(Json.stringify(rpcResponse, null, '\t'));
			}
			ws.on('message', function incoming(message :String) {
				handler(message, sender);
			});
		});
		wss.on('error', function(err) {
			promise.reject(err);
		});

		//Client infrastructure
		var clientConnection = new JsonRpcConnectionWebSocket('http://localhost:' + port);
		var clientProxy = t9.remoting.jsonrpc.Macros.buildRpcClient(jsonrpc.TestService1, true)
							.setConnection(clientConnection);

		var inputString = 'test';
		clientProxy.foo1(inputString)
			.then(function(result :String) {
				wss.close();
				if (result == '${inputString}done') {
					deferred.resolve(true);
				} else {
					promise.reject('unexpected response');
				}
			});

		return promise;
	}

	@timeout(3000)
	public function testServerSendingRPCCall () :Promise<Bool>
	{
		var promise = new DeferredPromise();

		var port = 8082;

		//Server infrastructure
		var wss = new WebSocketServer({port:port});

		//Bind your services to this object:
		var serverContext = new t9.remoting.jsonrpc.Context();

		//Create the service, then bind to the above context
		var serverService = new ServerService();
		serverContext.registerService(serverService);

		wss.on('connection', function connection(ws :WebSocket) {
			var serverClientThing = new JsonRpcConnectionWebSocketServer(ws, serverContext);
			var serverProxyToClient = t9.remoting.jsonrpc.Macros.buildRpcClient(jsonrpc.ClientService, true)
				.setConnection(serverClientThing);
			serverProxyToClient.testClientMethodCalledFromServer(2)
				.then(function(answer) {
					assertEquals(2+5, answer);
				});
		});
		wss.on('error', function(err) {
			promise.boundPromise.reject(err);
		});

		//Client infrastructure
		var clientConnection = new JsonRpcConnectionWebSocket('http://localhost:' + port);
		var clientRecieverService = new jsonrpc.ClientService();
		clientConnection.context.registerService(clientRecieverService);
		var clientProxyToServer = t9.remoting.jsonrpc.Macros.buildRpcClient(jsonrpc.ServerService, true)
				.setConnection(clientConnection);
		clientRecieverService.donePromise
			.then(function(arg) {
				clientProxyToServer.testServer(4)
					.then(function(answer) {
						assertEquals(4+5, answer);
						wss.close();
						promise.resolve(true);
					});
			});

		return promise.boundPromise;
	}
}

class ClientService
{
	@rpc({
		alias: 'clienttest'
	})
	public function testClientMethodCalledFromServer(arg1 :Int) :Promise<Int>
	{
		_deferred.resolve(true);
		return Promise.promise(arg1 + 5);
	}

	public var donePromise (default, null) :Promise<Bool>;
	var _deferred :promhx.deferred.DeferredPromise<Bool>;

	public function new()
	{
		_deferred = new promhx.deferred.DeferredPromise();
		donePromise = _deferred.boundPromise;
	}
}

class ServerService
{
	@rpc({
		alias: 'servertest'
	})
	public function testServer(arg1 :Int) :Promise<Int>
	{
		_deferred.resolve(arg1);
		return Promise.promise(arg1 + 5);
	}

	public var donePromise (default, null) :Promise<Int>;
	var _deferred :promhx.deferred.DeferredPromise<Int>;

	public function new()
	{
		_deferred = new promhx.deferred.DeferredPromise();
		donePromise = _deferred.boundPromise;
	}
}
