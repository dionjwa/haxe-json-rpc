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
import js.npm.bodyparser.BodyParser;
import js.npm.JsonRpcExpressTools;

import promhx.Promise;
import promhx.deferred.DeferredPromise;

using StringTools;

class TestExpressRoutes extends PromiseTest
{
	public function new() {}

	@Test
	@timeout(1000000)
	public function testExpressRoutes1 () :Promise<Bool>
	{
		var promise = new DeferredPromise();

		var context = new t9.remoting.jsonrpc.Context();

		context.registerService(jsonrpc.TestService3);

		var prefix = '/prefix';
		var app = Express.GetApplication();

		var router = Express.GetRouter();
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

			var url = 'http://localhost:${port}${prefix}/express-route-test/$arg1/$arg2';
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
		});

		return promise.boundPromise;
	}

	@Test
	@timeout(1000000)
	public function testExpressRoutes2 () :Promise<Bool>
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
		var arg3 = 45;

		httpServer.listen(port, function() {
			var url = 'http://localhost:${port}${prefix}/expressroutetest2alias/$arg1/$arg2?value3=${arg3}';
			get(url)
				.then(function(result :String) {
					var jsonRpcResult :ResponseDef = Json.parse(result + "");
					assertEquals(jsonRpcResult.result, '${arg1}::${arg2}::${arg3}');
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
		});

		return promise.boundPromise;
	}

	@Test
	@timeout(1000000)
	public function testExpressRoutes2Post () :Promise<Bool>
	{
		var promise = new DeferredPromise();

		var context = new t9.remoting.jsonrpc.Context();

		context.registerService(jsonrpc.TestService3);

		var app = Express.GetApplication();
		app.use(cast BodyParser.json());
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
		var arg3 = 45;

		var params = {
			value1: arg1,
			value2: arg2,
			value3: arg3
		}

		httpServer.listen(port, function() {
			var url = 'http://localhost:${port}${prefix}/expressroutetest2alias';

			// /$arg1/$arg2?value3=${arg3}
			post(url, params)
				.then(function(result :String) {
					var jsonRpcResult :ResponseDef = Json.parse(result + "");
					assertEquals(jsonRpcResult.result, '${arg1}::${arg2}::${arg3}');
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
		});

		return promise.boundPromise;
	}

	public static function get(url :String, ?timeout :Int = 0) :Promise<String>
	{
		return getBuffer(url, timeout)
			.then(function(buffer) {
				return buffer != null ? buffer.toString('utf8') : null;
			});
	}

	public static function post(url :String, data :Dynamic, ?timeout :Int = 0) :Promise<String>
	{
		return postBuffer(url, data, timeout)
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

	public static function postBuffer(url :String, data :Dynamic, ?timeout :Int = 0) :Promise<Buffer>
	{
		var promise = new DeferredPromise();
		var boundPromise = promise.boundPromise;
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
		var caller :{request:Dynamic->(IncomingMessage->Void)->ClientRequest} = url.startsWith('https') ? cast js.node.Https : cast js.node.Http;
		var options = js.node.Url.parse(url);

		var postOptions = {
			hostname: options.hostname,
			port: options.port,
			path: options.path,
			method: 'POST',
			headers: {
				'content-type': 'application/json'
			}
		};
		var request = null;
		try {
			request = caller.request(postOptions, cb);
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

			request.write(Json.stringify(data));
			request.end();

		} catch(err :Dynamic) {
			if (promise != null) {
				promise.boundPromise.reject({error:err, url:url});
				promise = null;
			}
		}
		return boundPromise;
	}

}