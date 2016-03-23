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

class BasicsTest extends PromiseTest
{
	public function new() {}

	@Test
	public function testStaticClassService ()
	{
		var context = new t9.remoting.jsonrpc.Context();
		jsonrpc.TestService3;
		context.registerService(jsonrpc.TestService3);
	}

	@Test
	public function testStaticClassServiceCalling () :Promise<Bool>
	{
		var deferred = new Deferred();
		var promise = deferred.promise();

		var context = new t9.remoting.jsonrpc.Context();

		context.registerService(jsonrpc.TestService3);

		var httpServer = Http.createServer(Routes.generatePostRequestHandler(context).bind(_, _, null));

		httpServer.on('error', function(err) {
			promise.reject(err);
		});

		var port = '8082';

		var clientConnection = new t9.remoting.jsonrpc.JsonRpcConnectionHttp('http://localhost:' + port);

		httpServer.listen(port, function() {
			clientConnection.request(Type.getClassName(jsonrpc.TestService3) + '.foo1', {input:'inputString'})
			.then(function(result :String) {
				httpServer.close(function() {
					if (result == 'inputStringdone') {
						deferred.resolve(true);
					} else {
						promise.reject('Unexpected result=$result != inputStringdone');
					}
				});
			})
			.catchError(function(err) {
				httpServer.close(function() {
					promise.reject(err);
				});
			});
		});

		return promise;
	}

	// public function testMacroClassServiceCalling() :Promise<Bool>
	// {
	// 	var deferred = new Deferred();
	// 	var promise = deferred.promise();

	// 	var context = new t9.remoting.jsonrpc.Context();

	// 	context.registerService(jsonrpc.TestService3);

	// 	var connection = new NodeConnectionJsonRpcHttp(context);

	// 	var httpServer = Http.createServer(function(req:IncomingMessage, res:ServerResponse) {
	// 		connection.handleRequest(req, res);
	// 	});

	// 	httpServer.on('error', function(err) {
	// 		promise.reject(err);
	// 	});

	// 	var port = '8082';

	// 	var clientConnection = new t9.remoting.jsonrpc.JsonRpcConnectionHttp('http://localhost:' + port);

	// 	httpServer.listen(port, function() {
	// 		clientConnection.request(Type.getClassName(jsonrpc.TestService3) + '.foo1', {input:'inputString'})
	// 			.then(function(result :String) {
	// 				httpServer.close(function() {
	// 					if (result == 'inputStringdone') {
	// 						deferred.resolve(true);
	// 					} else {
	// 						promise.reject('Unexpected result=$result != inputStringdone');
	// 					}
	// 				});
	// 			})
	// 			.catchError(function(err) {
	// 				httpServer.close(function() {
	// 					promise.reject(err);
	// 				});
	// 			});
	// 	});

	// 	return promise;
	// }

}