package jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.unit.async.PromiseTest;

import js.Node;
import js.node.Http;
import js.node.http.*;
import js.npm.Ws;


import promhx.Promise;
import promhx.Deferred;

import t9.js.jsonrpc.NodeConnectionJsonRpcWebSocket;
import t9.remoting.jsonrpc.JsonRpcConnectionWebSocket;

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
		var serverConnection = new NodeConnectionJsonRpcWebSocket(serverContext);

		wss.on('connection', function connection(ws :WebSocket) {
			var sender = function(rpcResponse :ResponseDef) {
				ws.send(Json.stringify(rpcResponse, null, '\t'));
			}
			ws.on('message', function incoming(message :String) {
				serverConnection.handleRequest(message, sender);
			});
		});
		wss.on('error', function(err) {
			promise.reject(err);
		});


		//Client infrastructure
		var clientConnection = new JsonRpcConnectionWebSocket('http://localhost:' + port);
		var clientProxy = t9.remoting.jsonrpc.Macros.buildRpcClient(jsonrpc.TestService1, clientConnection);

		var inputString = 'test';
		clientProxy.foo1({input:inputString})
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
}
