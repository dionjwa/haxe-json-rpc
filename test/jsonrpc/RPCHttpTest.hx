package jsonrpc;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.unit.async.PromiseTest;

import t9.js.jsonrpc.NodeConnectionJsonRpcHttp;

import js.Node;
import js.node.Http;
import js.node.http.*;

import promhx.Promise;
import promhx.Deferred;

class RPCHttpTest extends PromiseTest
{
	public function new() {}

	@Test
	public function testHttpRpc () :Promise<Bool>
	{
		var deferred = new Deferred();
		var promise = deferred.promise();

		var context = new t9.remoting.jsonrpc.Context();

		var service1 = new TestService1();
		var service2 = new TestService2();

		context.registerService(service1);
		context.registerService(service2);

		var connection = new NodeConnectionJsonRpcHttp(context);

		var httpServer = Http.createServer(function(req:HttpServerReq, res:ServerResponse) {
			connection.handleRequest(req, res);
		});

		httpServer.on('error', function(err) {
			promise.reject(err);
		});

		var port = '8082';

		var clientConnection = new t9.remoting.jsonrpc.JsonRpcConnectionHttp('http://localhost:' + port);

		// var inputString1 = ''

		httpServer.listen(port, function() {
			clientConnection.call(Type.getClassName(TestService1) + '.foo1', {input:'inputString'})
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

	@Test
	public function testHttpRpcAlias () :Promise<Bool>
	{
		var deferred = new Deferred();
		var promise = deferred.promise();

		var context = new t9.remoting.jsonrpc.Context();

		var service = new TestService1();
		context.registerService(service);

		var connection = new NodeConnectionJsonRpcHttp(context);

		var httpServer = Http.createServer(function(req:HttpServerReq, res:ServerResponse) {
			connection.handleRequest(req, res);
		});

		httpServer.on('error', function(err) {
			promise.reject(err);
		});

		var port = '8082';
		httpServer.listen(port, function() {
			var postData = Json.stringify({
				id: "1",
				method: 'fooalias',
				params: {input:'inputString'}
			});
			// An object of options to indicate where to post to
			var postOptions :js.node.Url.UrlObj = cast {
				host: 'localhost',
				port: port,
				path: '/',
				method: 'POST',
				headers: {
					'Content-Type': 'application/json-rpc',
					'Content-Length': postData.length
				}
			};
			// Set up the request
			var postReq = Http.request(postOptions, function(res) {
				res.setEncoding('utf8');
				var responseData = '';
				res.on('data', function (chunk) {
					responseData += chunk;
				});
				res.on('end', function () {
					httpServer.close(function() {
						var jsonRes = Json.parse(responseData);
						if (jsonRes.result == 'inputStringdone2') {
							deferred.resolve(true);
						} else {
							promise.reject(jsonRes);
						}
					});
				});
			});

			postReq.on('error', function(err) {
				promise.reject(err);
			});

			// post the data
			postReq.write(postData);
			postReq.end();
		});

		return promise;
	}

}