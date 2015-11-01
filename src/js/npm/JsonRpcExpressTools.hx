package js.npm;

import haxe.Json;

import js.npm.JsonRpc;
import js.npm.Express;
import js.npm.express.Request;
import js.npm.express.Response;
import js.npm.express.Middleware;
import js.support.Callback;

import promhx.Promise;

using StringTools;

typedef RpcFunction=Dynamic->Promise<Dynamic>;

class JsonRpcExpressTools
{

	// RPC end point. By the time you call this, you're sure
	// its a JsonRpc call. I.e. there is no next() called
	public static function rpc(methods :Map<String, RpcFunction>) :Request->Response->Void
	{
		return function(req :Request, res :Response) {
			rpcInternal(req, res, next, methods);
		};
	}

	static function rpcInternal(req :Request, res :Response, methods :Map<String, RpcFunction>) :Void
	{
		res.setHeader('Content-Type', 'application/json');
		var data :RequestDef;
		var body :String = js.npm.connect.BodyParser.body(req);
		try {
			data = Json.parse(body);
		} catch (err :Dynamic) {
			res.status(500)
				.send(Json.stringify({
					jsonrpc: '2.0',
					error: 'Failed to parse body ${body} err=$err'
				}));
			return;
		}
		var onError = function (err :Dynamic, ? statusCode : Int = 200) {
			res.status(statusCode)
				.send(Json.stringify({
					jsonrpc: '2.0',
					error: err,
					id: data.id
				}));
		};

		if (data.jsonrpc != '2.0') {
			onError({
				code: -32600,
				message: 'Bad Request. JSON RPC version is invalid or missing',
				data: null
			}, 400);
			return;
		}

		if (!methods.exists(data.method)) {
			onError({
				code: -32601,
				message: 'Method not found : ' + data.method + ', available methods:[' + [for (f in methods.keys()) f].join(', ') + ']'
			}, 404);
			return;
		}
		try {
			methods[data.method](data.params)
				.then(function(result) {
					var jsonStringResult :String;
					try {
						jsonStringResult = Json.stringify({
							jsonrpc: '2.0',
							result: result,
							error : null,
							id: data.id
						});
						res.status(200);
						res.send(jsonStringResult);
					} catch(err :Dynamic) {
						Log.error('Failed to stringify result=${result} err=$err');
						onError({
							code: -32603,
							message: 'Failed to stringify result=${result} err=$err',
							data: err
						}, 500);
					}
				}).catchError(function(err) {
					Log.error('Failed:' + err);
					onError({
						code: -32603,
						message: 'Failed:' + err,
						data: err
					}, 500);
				});
		} catch (e :Dynamic) {
			Log.error(e);
			onError({
				code: -32603,
				message: 'Exception at method call',
				data: e
			}, 500);
		}
	}
}