package t9.js.jsonrpc;

import haxe.DynamicAccess;
import haxe.Json;
import haxe.remoting.JsonRpc;

import t9.remoting.jsonrpc.Context;

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
			if (req.method != 'POST' || req.headers[untyped 'content-type'] != 'application/json-rpc') {
				if (next != null) {
					next();
				}
				return;
			}

			res.setTimeout(timeout);

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
				res.setHeader('Content-Type', 'application/json');
				if (buffer == null) {
					var responseError :ResponseDef = {
						id: JsonRpcConstants.JSONRPC_NULL_ID,
						error: {code:-32700, message:'Empty POST request'},
						jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
					};
					res.writeHead(400);
					res.end(stringify(responseError));
					return;
				}
				var content = buffer.toString('utf8');
				try {
					var body :RequestDef = Json.parse(content);
					var promise = context.handleRpcRequest(body);
					promise
						.then(function(rpcResponse :ResponseDef) {
							if (rpcResponse.error == null) {
								res.writeHead(200);
							} else {
								if (rpcResponse.error.code == 0 || rpcResponse.error.code == null) {
									res.writeHead(200);
								} else {
									Log.error(rpcResponse);
									res.writeHead(500);
								}
							}
							res.end(stringify(rpcResponse));
						})
						.catchError(function(err) {
							var responseError :ResponseDef = {
								id :body.id,
								error: {code:-32700, message:err.toString(), data:body},
								jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
							};
							Log.error(responseError);
							res.writeHead(500);
							res.end(stringify(responseError));
						});
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

			//If the path is just the RPC path, return all API definitions.
			if (pathPrefix != null && path.replace(pathPrefix, '').length == 0) {
				res.setHeader("Content-Type", "application/json");
				var definitions = context.methodDefinitions();
				res.writeHead(200);
				res.end(stringify(definitions));
				return;
			}

			var pathTokens = path.split('/');

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

			var body :RequestDef = {
				jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
				id: JsonRpcConstants.JSONRPC_NULL_ID,
				method: pathTokens[pathTokens.length - 1],
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
							if (rpcResponse.error.code == 0 || rpcResponse.error.code == null) {
								res.writeHead(200);
							} else {
								res.writeHead(500);
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
