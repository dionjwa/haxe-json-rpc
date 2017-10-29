package jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.unit.async.PromiseTest;

import js.Node;
import js.node.Http;
import js.node.http.*;
import js.npm.ws.*;

import promhx.Promise;
import promhx.Deferred;

import t9.js.jsonrpc.Routes;

// import t9.js.jsonrpc.NodeConnectionJsonRpcWebSocket;
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

	@Test
	public function testServerSendingRPCCall () :Promise<Bool>
	{
		var deferred = new Deferred();
		var promise = deferred.promise();

		var port = 8082;

		//Server infrastructure
		var wss = new WebSocketServer({port:port});
		var serverContext = new t9.remoting.jsonrpc.Context();
		var service = new TestService1();

		var sendStuff = function(count :Int, ws :WebSocket) {
			ws.send(Json.stringify({'id':count, 'method':'test', params:{'count':count}, jsonrpc:JsonRpcConstants.JSONRPC_VERSION_2}, null, '\t'));
		};
		wss.on('connection', function connection(ws :WebSocket) {
			sendStuff(1, ws);
			ws.on('message', function incoming(message :String) {
				var res :ResponseDef = Json.parse(message);
				assertTrue(res.id == res.result);
				if (res.id == 1) {
					sendStuff(2, ws);
				} else if (res.id == 2) {
					wss.close();
					deferred.resolve(true);
				} else {
					throw "There was only two messages";
				}
			});
		});
		wss.on('error', function(err) {
			promise.reject(err);
		});

		//Client infrastructure
		var clientConnection = new JsonRpcConnectionWebSocket('http://localhost:' + port);
		var gotMessages = new Array<Bool>();
		clientConnection.incoming.then(function(incoming:IncomingObj<Int>) {
			incoming.sendResponse(incoming.id);
		});

		return promise;
	}
}
