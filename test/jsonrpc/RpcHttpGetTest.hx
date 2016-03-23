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

class RpcHttpGetTest extends PromiseTest
{
	public function new() {}

	@Test
	public function testHttpGetRpc () :Promise<Bool>
	{
		var deferred = new Deferred();
		var promise = deferred.promise();

		var context = new t9.remoting.jsonrpc.Context();

		var service1 = new TestService1();
		var service2 = new TestService2();

		context.registerService(service1);
		context.registerService(service2);

		var httpServer = Http.createServer(Routes.generateGetRequestHandler(context).bind(_, _, null));

		httpServer.on('error', function(err) {
			promise.reject(err);
		});

		var port = '8082';

		var clientConnection = new t9.remoting.jsonrpc.JsonRpcConnectionHttpGet('http://localhost:' + port);

		httpServer.listen(port, function() {
			clientConnection.request(Type.getClassName(TestService1) + '.foo1', {input1:'inputString', input2:'inputString2'})
			.then(function(result :String) {
				httpServer.close(function() {
					if (result == 'inputStringdone') {
						deferred.resolve(true);
					} else {
						promise.reject('Unexpected result=$result != inputStringdone');
					}
				});
			});
		});

		return promise;
	}
}