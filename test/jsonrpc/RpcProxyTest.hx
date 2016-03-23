package jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.unit.async.PromiseTest;

import t9.js.jsonrpc.Routes;

import js.Node;
import js.node.Http;
import js.node.http.*;

import promhx.Promise;
import promhx.Deferred;

class RpcProxyTest extends PromiseTest
{
	public function new() {}

	@Test
	public function testHttpProxyRpc () :Promise<Bool>
	{
		var deferred = new Deferred();
		var promise = deferred.promise();

		var port = '8082';

		//Server infrastructure
		var serverContext = new t9.remoting.jsonrpc.Context();
		var service = new TestService1();
		serverContext.registerService(service);


		//Client infrastructure
		var clientConnection = new t9.remoting.jsonrpc.JsonRpcConnectionHttp('http://localhost:' + port);
		var clientProxy = t9.remoting.jsonrpc.Macros.buildRpcClient(jsonrpc.TestService1)
							.setConnection(clientConnection);

		//Set up the server and begin
		var httpServer = Http.createServer(Routes.generatePostRequestHandler(serverContext).bind(_, _, null));

		httpServer.on('error', function(err) {
			promise.reject(err);
		});

		var inputString = 'test';
		httpServer.listen(port, function() {
			clientProxy.foo1(inputString)
				.then(function(result :String) {
					httpServer.close(function() {
						if (result == '${inputString}done') {
							deferred.resolve(true);
						} else {
							promise.reject('unexpected response');
						}
					});
				});
		});

		return promise;
	}
}
