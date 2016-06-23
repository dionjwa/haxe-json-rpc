package t9.js.jsonrpc;

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

	public static function generatePostRequestHandler (context :Context)
	{
		return function(req :IncomingMessage, res :ServerResponse, next :?Dynamic->Void) :Void {
			if (req.method != 'POST' || req.headers[untyped 'content-type'] != 'application/json-rpc') {
				if (next != null) {
					next();
				}
				return;
			}

			//Get the POST data
			var buffer :Buffer = null;
			req.addListener(ReadableEvent.Data, function(chunk) {
				if (buffer == null) {
					buffer = chunk;
				} else {
					buffer = Buffer.concat([buffer, chunk]);
				}
			});

			req.addListener(ReadableEvent.End, function() {
				res.setHeader('Content-Type', 'application/json');
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
							res.end(Json.stringify(rpcResponse, null, '\t'));
						})
						.catchError(function(err) {
							var responseError :ResponseDef = {
								id :body.id,
								error: {code:-32700, message:err.toString(), data:body},
								jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
							};
							Log.error(responseError);
							res.writeHead(500);
							res.end(Json.stringify(responseError, null, '\t'));
						});
				} catch (err :Dynamic) {
					var responseError :ResponseDef = {
						id :0,
						error: {code:-32700, message:'Invalid JSON was received by the server.\n' + err.toString(), data:content},
						jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
					};
					Log.error(responseError);
					res.writeHead(500);
					res.end(Json.stringify(responseError, null, '\t'));
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
	public static function generateGetRequestHandler (context :Context, ?pathPrefix :String)
	{
		return function(req :IncomingMessage, res :ServerResponse, next :?Dynamic->Void) :Void {
			if (req.method != 'GET') {
				if (next != null) {
					next();
				}
				return;
			}
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
				res.end(Json.stringify(definitions, null, '\t'));
				return;
			}

			var pathTokens = path.split('/');

			var body :RequestDef = {
				jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2,
				id: JsonRpcConstants.JSONRPC_NULL_ID,
				method: pathTokens[pathTokens.length - 1],
				params: parts.query
			}

			res.setHeader("Content-Type", "application/json");

			try {
				var promise = context.handleRpcRequest(body);
				promise
					.then(function(rpcResponse :ResponseDef) {
						if (rpcResponse.error == null) {
							res.writeHead(200);
						} else {
							if (rpcResponse.error.code == 0 || rpcResponse.error.code == null) {
								res.writeHead(200);
							} else {
								res.writeHead(500);
							}
						}
						res.end(Json.stringify(rpcResponse, null, '\t'));
					})
					.catchError(function(err) {
						var responseError :ResponseDef = {
							id :body.id,
							error: {code:-32700, message:err},
							jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
						};
						res.writeHead(500);
						res.end(Json.stringify(responseError, null, '\t'));
					});
			} catch (e :Dynamic) {
				var responseError :ResponseDef = {
					id :body.id,
					error: {code:-32700, message:'Invalid JSON was received by the server.', data:e},
					jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
				};
				res.writeHead(500);
				res.end(Json.stringify(responseError, null, '\t'));
			}
		}
	}
}
