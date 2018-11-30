package js.npm;

import haxe.Json;
import haxe.DynamicAccess;
import haxe.remoting.JsonRpc;
import t9.remoting.jsonrpc.*;

import js.node.http.*;
import js.npm.express.*;
import js.npm.bodyparser.BodyParser;

import promhx.Promise;

import t9.remoting.jsonrpc.Context;

using StringTools;

typedef RpcFunction=Dynamic->Promise<Dynamic>;

class JsonRpcExpressTools
{
	public static function callExpressRequest(context :Context, jsonRpcReq :RequestDef, res :ExpressResponse, stripJsonRpcShell :Bool, next :?Dynamic->Void, ?timeout :Int = 120000) :Void
	{
		if (!context.exists(jsonRpcReq.method)) {
			next();
			return;
		}
		res.setTimeout(timeout);
		res.setHeader('Content-Type', 'application/json');
		context.handleRpcRequest(jsonRpcReq)
			.then(function(rpcResponse :ResponseDef) {
				var status =
					if (rpcResponse.error == null) {
						200;
					} else {
						if (rpcResponse.error.httpStatusCode != null) {
							rpcResponse.error.httpStatusCode;
						} else {
							if (rpcResponse.error.code == JsonRpcErrorCode.InvalidParams) {
								400;
							} else if (rpcResponse.error.code >= 200 && rpcResponse.error.code <= 599) {
								rpcResponse.error.code;
							} else {
								500;
							}
						}
					};
				res.writeHead(status);
				if (stripJsonRpcShell) {
					if (status == 200) {
						if (untyped __typeof__(rpcResponse.result) == 'string') {
							res.end(rpcResponse.result);
						} else {
							res.end(stringify(rpcResponse.result));
						}
					} else {
						res.end(stringify(rpcResponse.error));
					}
				} else {
					res.end(stringify(rpcResponse));
				}
			})
			.catchError(function(err) {
				next(err);
			});
	}

	public static function addExpressRoutes(app :Dynamic, context :Context)
	{
		function addMethodToRouter(method :RemoteMethodDefinition) {

			var url = '/${method.alias}';
			if (method.alias == null) {
				url = '/${method.method.replace('.', '').replace('-', '')}';
			}
			if (method.args != null) {
				for (arg in method.args) {
					if (!arg.optional) {
						url = '${url}/:${arg.name}';
					}
				}
			}

			app.get(url, function(req :ExpressRequest, res :ExpressResponse, next :?Dynamic->Void) {
				//Get all possible parameters
				var params :DynamicAccess<Dynamic> = {};
				if (req.params != null) {
					for (key in Reflect.fields(req.params)) {
						try {
							params[key] = Json.parse(Reflect.field(req.params, key));
						} catch(err :Dynamic) {
							params[key] = Reflect.field(req.params, key);
						}
					}
				}
				if (req.query != null) {
					for (key in Reflect.fields(req.query)) {
						try {
							params[key] = Json.parse(Reflect.field(req.query, key));
						} catch(err :Dynamic) {
							params[key] = Reflect.field(req.query, key);
						}
					}
				}

				var jsonRpcRequest :RequestDef = {
					method: method.method,
					params: params,
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
					id: JsonRpcConstants.JSONRPC_NULL_ID
				};

				callExpressRequest(context, jsonRpcRequest, res, true, next);
			});

			var postUrl = '/${method.alias}';
			if (method.alias == null) {
				postUrl = '/${method.method.replace('.', '').replace('-', '')}';
			}

			app.post(postUrl, function(req :ExpressRequest, res :ExpressResponse, next :?Dynamic->Void) {
				//Get all possible parameters
				var params :DynamicAccess<Dynamic> = BodyParser.body(cast req);
				var jsonRpcRequest :RequestDef = {
					method: method.method,
					params: params,
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
					id: JsonRpcConstants.JSONRPC_NULL_ID
				};

				callExpressRequest(context, jsonRpcRequest, res, true, next);
			});
		}

		app.get(function(req :ExpressRequest, res :ExpressResponse, next :?Dynamic->Void) {
			res.json({methods:context.methodDefinitions()});
		});

		for (method in context.methodDefinitions()) {
			addMethodToRouter(method);
		}
	}

	public static function createRpcRouter(context :Context) //:Request->Response->(Void->Void)->Void
	{
		return rpc(context._methods);
	}

	// RPC end point. By the time you call this, you're sure
	// its a JsonRpc call. I.e. there is no next() called
	public static function rpc(methods :Map<String, RpcFunction>) :ExpressRequest->ExpressResponse->Void
	{
		return function(req, res) {
			rpcInternal(req, res, methods);
		};
	}

	static function rpcInternal(req :ExpressRequest, res :ExpressResponse, methods :Map<String, RpcFunction>) :Void
	{
		res.setHeader('Content-Type', 'application/json');
		var data :RequestDef;
		var body :String = js.npm.bodyparser.BodyParser.body(cast req);
		try {
			data = Json.parse(body);
		} catch (err :Dynamic) {
			res.status(500)
				.send(Json.stringify({
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
					error: 'Failed to parse body ${body} err=$err'
				}));
			return;
		}
		var onError = function (err :Dynamic, ? statusCode : Int = 200) {
			res.status(statusCode)
				.send(Json.stringify({
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
					error: err,
					id: data.id
				}));
		};

		if (data.jsonrpc != JsonRpcConstants.JSONRPC_VERSION_2) {
			onError({
				code: -32600,
				message: 'Bad Request. JSON RPC version is invalid or missing',
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
							jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
							result: result,
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

	inline static function stringify(obj :Dynamic) :String
	{
		return Json.stringify(obj, null, '  ');
	}
}
