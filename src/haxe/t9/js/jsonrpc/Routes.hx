package t9.js.jsonrpc;

import haxe.DynamicAccess;
import haxe.Json;
import haxe.remoting.JsonRpc;

import t9.remoting.jsonrpc.Context;
import js.npm.JsonRpcExpressTools;

#if nodejs
	import js.Node;
	import js.node.Url;
	import js.node.Http;
	import js.node.http.*;
	import js.node.stream.Readable;
	import js.node.buffer.Buffer;
#end

using StringTools;

class Routes
{
	public static function createMethodAndParamsFromExpressUrl(req :IncomingMessage) :{method :String, params:Dynamic}
	{
		if (untyped req.route == null) {
			//Not an express app
			return null;
		}
		var params :DynamicAccess<Dynamic> = {};
		var originalUrl :String = untyped req.originalUrl;
		var reqParams :DynamicAccess<Dynamic> = untyped req.params;
		if (reqParams != null) {
			for (key in reqParams.keys()) {
				params.set(key, Json.parse(reqParams.get(key)));
			}
		}
		var path :String = untyped req.route.path;
		for (key in params.keys()) {
			path = path.replace(':${key}', '');
		}
		path = path.replace('//', '/');
		if (path.endsWith('/')) {
			path = path.substr(0, path.length - 1);
		}
		if (untyped req.query != null) {
			var query :DynamicAccess<Dynamic> = untyped req.query;
			for (key in query.keys()) {
				for (key in reqParams.keys()) {
					params.set(key, Json.parse(query.get(key)));
				}
			}
		}
		return {
			method: path,
			params: params
		};

	}

	public static function generateJsonRpcRequestHandler (context :Context)
	{
		return function handleRequest (message :String, sender :ResponseDef->Void) {
			var request :RequestDef = null;
			try {
				request = Json.parse(message);
			} catch (err :Dynamic) {
				Log.error(err);
				return;
			}

			if (request.jsonrpc == null || request.method == null) {
				Log.error('Not a jsonrpc message=' + message);
				return;
			}

			context.handleRpcRequest(request)
				.then(function(rpcResponse :ResponseDef) {
					sender(rpcResponse);
				});
		}
	}

	public static function generatePostRequestHandler (context :Context, ?timeout :Int = 120000)
	{
		return function(req :IncomingMessage, res :ServerResponse, next :?Dynamic->Void) :Void {
			if (req.method != 'POST' || !(req.headers[untyped 'content-type'] == 'application/json-rpc' || req.headers[untyped 'content-type'] == 'application/json')) {
				if (next != null) {
					next();
				}
				return;
			}

			//The body may have already been parsed
			var requestBody :Dynamic = Reflect.field(req, "body");
			if (requestBody != null && req.headers[untyped 'content-type'] == 'application/json') {
				if (untyped __typeof__(requestBody) == 'string') {
					var body :RequestDef = Json.parse(requestBody);
					JsonRpcExpressTools.callExpressRequest(context, body, cast res, next, timeout);
				} else {
					JsonRpcExpressTools.callExpressRequest(context, requestBody, cast res, next, timeout);
				}
			} else {
				//Get the POST data
				var buffer :Buffer = null;
				req.addListener(ReadableEvent.Data, function(chunk) {
					if (buffer == null) {
						buffer = chunk;
					} else {
						buffer = Buffer.concat([buffer, chunk]);
					}
				});

				//Handle errors in case they are thrown which will cause a crash
				var errorOrAborted = false;
				req.once(ReadableEvent.Error, function(err) {
					Log.error('Error in JSONRPC post request handler err=${Json.stringify(err)}');
					errorOrAborted = true;
				});
				req.once('aborted', function() {
					errorOrAborted = true;
				});

				req.addListener(ReadableEvent.End, function() {
					if (errorOrAborted) {
						return;
					}
					if (buffer == null) {
						var responseError :ResponseDef = {
							id: JsonRpcConstants.JSONRPC_NULL_ID,
							error: {code:-32700, message:'Empty POST request'},
							jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
						};
						res.setHeader('Content-Type', 'application/json');
						res.writeHead(400);
						res.end(stringify(responseError));
						return;
					}
					var content = buffer.toString('utf8');
					Reflect.setField(req, 'body', content);
					try {
						var body :RequestDef = Json.parse(content);
						JsonRpcExpressTools.callExpressRequest(context, body, cast res, next, timeout);
					} catch (err :Dynamic) {
						var responseError :ResponseDef = {
							id: JsonRpcConstants.JSONRPC_NULL_ID,
							error: {code:-32700, message:'Invalid JSON was received by the server.\n' + err.toString(), data:content},
							jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
						};
						Log.error(responseError);
						res.writeHead(400);
						res.end(stringify(responseError));
					}
				});
			}
		}
	}

	/**
	 * Create an express handler that accepts JSON-RPC requests encoded in
	 * the url and query parameters.
	 * @param  context :Context      [description]
	 * @return         [description]
	 */
	public static function generateGetRequestHandler (context :Context, ?pathPrefix :String, ?timeout :Int = 120000)
	{
		return function(req :IncomingMessage, res :ServerResponse, next :?Dynamic->Void) :Void {
			if (req.method != 'GET') {
				if (next != null) {
					next();
				}
				return;
			}

			res.setTimeout(timeout);

			var parts = Url.parse(req.url, true);//Parse the querystring as an object also
			var path = parts.pathname;
			if (path == null) {
				if (next != null) {
					next();
				}
				return;
			}

			if (pathPrefix != null) {
				path = path.replace(pathPrefix, '');
			}

			//If the path is just the RPC path, return all API definitions.
			if (pathPrefix != null && path.replace(pathPrefix, '').length == 0) {
				res.setHeader("Content-Type", "application/json");
				var definitions = context.methodDefinitions();
				res.writeHead(200);
				res.end(stringify(definitions));
				return;
			}

			var pathTokens = path.trim().split('/').filter(function(s) return s != null && s.trim().length > 0);

			var query :DynamicAccess<String> = parts.query;
			var params :DynamicAccess<Dynamic> = {};
			if (query != null) {
				for (k in query.keys()) {
					try {
						var parsed = Json.parse(query[k]);
						params[k] = parsed;
					} catch(err :Dynamic) {
						params[k] = query[k];
					}
				}
			}

			var method = pathTokens.shift();
			var methodDefinition = context.getMethodDefinition(method);
			if (methodDefinition == null) {
				if (next != null) {
					next();
					return;
				} else {
					var responseError :ResponseDef = {
						id: null,
						error: {code:-32700, message:'No RPC method: "$method"'},
						jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
					};
					//501 Not Implemented
					res.writeHead(501);
					res.end(stringify(responseError));
					return;
				}
			}

			var requiredArgumentDefinitions = methodDefinition.args.filter(function(d) return !d.optional);
			for (i in 0...requiredArgumentDefinitions.length) {
				if (pathTokens[i] == null) {
					break;
				}
				var argName = requiredArgumentDefinitions[i].name;
				var argValueFromUrl :Dynamic = pathTokens[i];
				try {
					argValueFromUrl = Json.parse(argValueFromUrl);
				} catch(e :Dynamic) {}

				params[argName] = argValueFromUrl;
			}

			var body :RequestDef = {
				jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
				id: JsonRpcConstants.JSONRPC_NULL_ID,
				method: method,
				params: params
			}

			//Handle errors in case they are thrown which will cause a crash
			var errorOrAborted = false;
			req.once(ReadableEvent.Error, function(err) {
				Log.error('Error in JSONRPC post request handler err=${Json.stringify(err)}');
				errorOrAborted = true;
			});
			req.once('aborted', function() {
				errorOrAborted = true;
			});

			res.setHeader("Content-Type", "application/json");

			try {
				var promise = context.handleRpcRequest(body);
				promise
					.then(function(rpcResponse :ResponseDef) {
						if (errorOrAborted) {
							return;
						}
						if (rpcResponse.error == null) {
							res.writeHead(200);
						} else {
							if (rpcResponse.error.httpStatusCode != null) {
								res.writeHead(rpcResponse.error.httpStatusCode);
							} else {
								if (rpcResponse.error.code >= 200 && rpcResponse.error.code <= 599) {
									res.writeHead(rpcResponse.error.code);
								} else {
									res.writeHead(500);
								}
							}
						}
						res.end(stringify(rpcResponse));
					})
					.catchError(function(err) {
						if (errorOrAborted) {
							return;
						}
						var responseError :ResponseDef = {
							id: body.id,
							error: {code:-32700, message:err},
							jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
						};
						res.writeHead(500);
						res.end(stringify(responseError));
					});
			} catch (e :Dynamic) {
				if (errorOrAborted) {
					return;
				}
				var responseError :ResponseDef = {
					id: body.id,
					error: {code:-32700, message:'Invalid JSON was received by the server.', data:e},
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
				};
				res.writeHead(400);
				res.end(stringify(responseError));
			}
		}
	}

	inline static function stringify(obj :Dynamic) :String
	{
		return Json.stringify(obj, null, '  ');
	}
}
