package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;
import haxe.Json;

#if nodejs
	import promhx.Deferred;
	import promhx.Stream;
#else
	import js.Promise;
#end

import js.npm.ws.WebSocket;

class JsonRpcConnectionWebSocketServer
	implements JsonRpcConnection
{
	public var context (get, null) :Context;

	public function new(ws :WebSocket, context :Context)
	{
		_promises = new Map();
		_context = context;
		_ws = ws;
		_ws.onmessage = onMessage;
		_ws.onclose = function(reason :Int) {
			this.dispose();
			return null;
		};
	}

	public function dispose()
	{
		if (_ws != null) {
			_ws.onmessage = null;
			_ws.onclose = null;
			_ws.close();
			_ws = null;
		}
		_promises = null;
		_context = null;
	}

	function handleIncomingMessage(message :RequestDef)
	{
		_context.handleRpcRequest(message)
			.then(function(response :ResponseDef) {
				if (_ws.readyState == WebSocket.OPEN) {
					_ws.send(Json.stringify(response));
				} else {
					trace('Error: got JSON-RPC response, but websocket is not open response=${response} ws.readyState=${_ws.readyState}');
				}
			})
			.catchError(function(err) {
				trace('Error: got JSON-RPC err message=${message} err=${err}');
			});
	}

	function onMessage(data :Dynamic, flags :WebSocketMessageFlag)
	{
		if (flags != null && flags.binary) {
			trace('Cannot handle binary websocket data=${data} flags=${flags}, ignoring message');
			return;
		}
		try {
			var json :Dynamic = Json.parse(data.data);
			if (json.jsonrpc != JsonRpcConstants.JSONRPC_VERSION_2) {
				trace('Not json-rpc type:"${data}"');
				return;
			}
			if (json.method != null && (json.error == null && json.result == null)) {
				handleIncomingMessage(json);
				return;
			}
			if (json.id == null) {
				trace('id is null in json-rpc response:"${data}"');
				return;
			}
			var promiseData = _promises[json.id];
			if (promiseData == null) {
				trace('No promise mapped to:"${data}"');
				return;
			}
			_promises.remove(json.id);
			promiseData.resolve(json);
		} catch (err :Dynamic) {
			trace(err);
			// trace('Failed to Json.parse:"${data}"');
		}
	}

	public function request(method :String, ?params :Dynamic) :Promise<Dynamic>
	{
		var request :RequestDef = {
			id: (++_idCount) + '',
			method: method,
			params: params,
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
		};
		return callRequestInternal(request)
			.then(function(response: ResponseDef) {
				if (response.error != null) {
					throw Std.string(response.error);
				}
				return response.result;
			});
	}

	public function notify(method :String, ?params :Dynamic) :Promise<Bool>
	{
		var request :RequestDef = {
			method: method,
			params: params,
			jsonrpc: JsonRpcConstants.JSONRPC_VERSION_2
		};
		return callNotifyInternal(request);
	}

	function callRequestInternal(request :RequestDef) :Promise<ResponseDef>
	{
#if ((promise == "js.npm.bluebird.Bluebird") || (promise == "js.Promise"))
		var internalResolve = null;
		var val = null;
		var resolver = function(v) {
			val = v;
			if (internalResolve != null) {
				internalResolve(v);
			}
		}
		var promise = new Promise(function(resolve, reject) {
			if (val != null) {
				resolver(val);
			} else {
				internalResolve = resolve;
			}
		});

		var requestString = Json.stringify(request);
		_ws.send(requestString);
		_promises.set(request.id, {request:request, resolve:resolver});
		return promise;
#else
		var deferred = new Deferred<ResponseDef>();
		var promise = deferred.promise();

		_promises[request.id] = {request:request, resolve:deferred.resolve};

		var requestString = Json.stringify(request);
		_ws.send(requestString);

		return promise;
#end
	}

	function callNotifyInternal(request :RequestDef) :Promise<Bool>
	{
#if ((promise == "js.npm.bluebird.Bluebird") || (promise == "js.Promise"))
		return new Promise(function(resolve, reject) {
			var requestString = Json.stringify(request);
			getConnection()
				.then(function(ws :WebSocketConnection) {
					ws.send(requestString);
					resolve(true);
				})
				.error(reject);
		});
#else
		var deferred = new Deferred<Bool>();
		var promise = deferred.promise();

		var requestString = Json.stringify(request);

		_ws.send(requestString);
		deferred.resolve(true);

		return promise;
#end
	}

	function get_ws() :WebSocket
	{
		return _ws;
	}

	function get_context() :Context
	{
		return _context;
	}

	var _idCount :Int = 0;
	var _ws :WebSocket;
	var _promises :Map<String, {request: RequestDef, resolve:ResponseDef->Void}>;
	var _context :Context;
}
