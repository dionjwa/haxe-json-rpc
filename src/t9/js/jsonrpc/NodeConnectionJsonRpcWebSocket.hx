package t9.js.jsonrpc;

#if !nodejs
#error
#end

import haxe.Json;
import haxe.remoting.JsonRpc;
import t9.remoting.jsonrpc.Context;

import js.Node;
import js.npm.Ws;

using StringTools;

class NodeConnectionJsonRpcWebSocket
{
	var _context :Context;

	public function new (ctx :Context)
	{
		_context = ctx;
	}

	public function handleRequest (message :String, sender :ResponseDef->Void) :Bool
	{
		var request :RequestDef = null;
		try {
			request = Json.parse(message);
		} catch (err :Dynamic) {
			Log.error(err);
			return false;
		}

		if (request.jsonrpc == null || request.method == null) {
			Log.info('Not a jsonrpc message=' + message);
			return false;
		}

		_context.handleRpcRequest(request)
			.then(function(rpcResponse :ResponseDef) {
				sender(rpcResponse);
			});

		return true;
	}
}
