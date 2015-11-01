package t9.js.jsonrpc;

#if !nodejs
#error
#end

import haxe.Json;
import haxe.remoting.JsonRpc;

import t9.remoting.jsonrpc.Context;

import js.Node;
import js.node.Url;
import js.node.Http;
import js.node.http.*;

using StringTools;

class NodeConnectionJsonRpcHttp
{
	var _context :Context;

	public function new (ctx :Context)
	{
		_context = ctx;
	}

	public function handleRequest (req :HttpServerReq, res :ServerResponse) :Bool
	{
		if (req.method != "POST" || req.headers[untyped "content-type"] != 'application/json-rpc') {
			return false;
		}

		//Get the POST data
		req.setEncoding("utf8");
		var content = "";

		var dataListener = function(chunk) {
			content += chunk;
		};
		req.addListener("data", dataListener);

		req.addListener("end", function() {
			req.removeListener("data", dataListener);
			res.setHeader("Content-Type", "application/json");

			try {
				var body :RequestDef = Json.parse(content);
				var promise = _context.handleRpcRequest(body);
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
							jsonrpc: "2.0"
						};
						res.writeHead(500);
						res.end(Json.stringify(responseError, null, '\t'));
					});
			} catch (e :Dynamic) {
				var responseError :ResponseDef = {
					id :0,
					error: {code:-32700, message:'Invalid JSON was received by the server.', data:content},
					jsonrpc: "2.0"
				};
				res.writeHead(500);
				res.end(Json.stringify(responseError, null, '\t'));
			}
		});
		return true;
	}
}
