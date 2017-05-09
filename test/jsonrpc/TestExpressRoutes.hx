package jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.unit.async.PromiseTest;

import t9.js.jsonrpc.Routes;

import js.Node;
import js.node.Buffer;
import js.node.stream.*;
import js.node.stream.Readable;
import js.node.stream.Writable;
import js.node.Http;
import js.node.http.*;

import js.npm.express.Express;
import js.npm.JsonRpcExpressTools;

import promhx.Promise;
import promhx.deferred.DeferredPromise;

using StringTools;

class TestExpressRoutes extends PromiseTest
{
	public function new() {}

	@Test
	@timeout(1000000)
	public function testExpressRoutes () :Promise<Bool>
	{
		var promise = new DeferredPromise();

		var context = new t9.remoting.jsonrpc.Context();

		context.registerService(jsonrpc.TestService3);

		var app = Express.GetApplication();
		var router = Express.GetRouter();

		var prefix = '/prefix';
		app.use(prefix, cast router);

		JsonRpcExpressTools.addExpressRoutes(router, context);


		var httpServer = Http.createServer(cast app);

		httpServer.on('error', function(err) {
			trace(err);
			if (promise != null) {
				promise.boundPromise.reject(true);
				promise = null;
			}
		});

		var port = '8082';

		var arg1 = "someStringArg";
		var arg2 = 42;

		httpServer.listen(port, function() {
			var url = 'http://localhost:${port}${prefix}/foo/bar/$arg1/$arg2';
			get(url)
				.then(function(result :String) {
					var jsonRpcResult :ResponseDef = Json.parse(result + "");
					assertEquals(jsonRpcResult.result, '${arg1}::${arg2}');
					if (promise != null) {
						promise.resolve(true);
						promise = null;
					}
					return true;
				})
				.errorPipe(function(err) {
					trace(err);
					if (promise != null) {
						promise.boundPromise.reject(err);
						promise = null;
					}
					return Promise.promise(false);
				})
				.then(function(_) {
					httpServer.close(function() {});
				});
			// clientConnection.request(Type.getClassName(jsonrpc.TestService3) + '.foo1', {input:'inputString'})
			// .then(function(result :String) {
			// 	httpServer.close(function() {
			// 		if (result == 'inputStringdone') {
			// 			deferred.resolve(true);
			// 		} else {
			// 			promise.reject('Unexpected result=$result != inputStringdone');
			// 		}
			// 	});
			// })
			// .catchError(function(err) {
				// httpServer.close(function() {
				// 	promise.resolve(true);
				// 	// promise.boundPromise.reject(err);
				// });
			// });
		});

		return promise.boundPromise;
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
	// 
	// 
	



	public static function get(url :String, ?timeout :Int = 0) :Promise<String>
	{
		return getBuffer(url, timeout)
			.then(function(buffer) {
				return buffer != null ? buffer.toString('utf8') : null;
			});
	}

	public static function getBuffer(url :String, ?timeout :Int = 0) :Promise<Buffer>
	{
		var promise = new DeferredPromise();
		var responseString = '';
		var responseBuffer :Buffer = null;
		var cb = function(res :IncomingMessage) {
			res.on(ReadableEvent.Error, function(err) {
				if (promise != null) {
					promise.boundPromise.reject({error:err, url:url});
					promise = null;
				} else {
					Log.error({error:err, stack:(err.stack != null ? err.stack : null)});
				}
			});

			res.on(ReadableEvent.Data, function(chunk :Buffer) {
				if (responseBuffer == null) {
					responseBuffer = chunk;
				} else {
					responseBuffer = Buffer.concat([responseBuffer, chunk]);
				}
			});
			res.on(ReadableEvent.End, function() {
				if (promise != null) {
					if (res.statusCode < 200 || res.statusCode > 299) {
						promise.boundPromise.reject(responseBuffer);
					} else {
						promise.resolve(responseBuffer);
					}
					promise = null;
				}
			});
		}
		var caller :{get:String->(IncomingMessage->Void)->ClientRequest} = url.startsWith('https') ? cast js.node.Https : cast js.node.Http;
		var request = null;
		try {
			request = caller.get(url, cb);
			request.on(WritableEvent.Error, function(err) {
				if (promise != null) {
					promise.boundPromise.reject({error:err, url:url});
					promise = null;
				} else {
					Log.error(err);
				}
			});
			if (timeout > 0) {
				request.setTimeout(timeout, function() {
					var err = {url:url, error:'timeout', timeout:timeout};
					if (promise != null) {
						promise.boundPromise.reject(err);
						promise = null;
					} else {
						Log.error(err);
					}
				});
			}
		} catch(err :Dynamic) {
			if (promise != null) {
				promise.boundPromise.reject({error:err, url:url});
				promise = null;
			}
		}
		return promise.boundPromise;
	}

}