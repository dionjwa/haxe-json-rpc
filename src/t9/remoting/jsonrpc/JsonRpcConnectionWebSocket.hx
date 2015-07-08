package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;
import haxe.Json;

import promhx.Promise;
import promhx.Deferred;

import t9.websockets.WebSocketConnection;

class JsonRpcConnectionWebSocket
	implements JsonRpcConnection
{
	public static function urlConnect(url :String)
	{
		return new JsonRpcConnectionWebSocket(url);
	}

	public var ws (get, null):WebSocketConnection;

	public function new(url)
	{
		_url = url;
		_promises = new Map();
		_ws = new WebSocketConnection(_url);

		_ws.registerOnMessage(onMessage);
	}

	function onMessage(data :String, ?flags :{binary:Bool})
	{
		if (flags != null && flags.binary) {
			Log.warn('Cannot handle binary websocket data, ignoring message');
			return;
		}
		try {
			var json :Dynamic = Json.parse(data);
			if (json.jsonrpc != '2.0') {
				Log.error('Not json-rpc type:"$data"');
				return;
			}
			if (json.method != null && (json.error == null && json.result == null)) {
				Log.error('Cannot yet handle server sending json-rpc requests:"$data"');
				return;
			}
			if (json.id == null) {
				Log.error('id is null in json-rpc response:"$data"');
				return;
			}
			var promiseData = _promises[json.id];
			if (promiseData == null) {
				Log.error('No promise mapped to:"$data"');
				return;
			}
			_promises.remove(json.id);
			promiseData.deferred.resolve(json);
		} catch (err :Dynamic) {
			Log.error('Failed to Json.parse:"$data"');
		}
	}

	function getConnection() :Promise<WebSocketConnection>
	{
		return _ws.getReady();
	}

	public function call(method :String, ?params :Dynamic) :Promise<Dynamic>
	{
		var request :RequestDef = {
			id: (++_idCount) + '',
			method: method,
			params: params,
			jsonrpc: "2.0"
		};
		return callInternal(request)
			.then(function(response: ResponseDef) {
				if (response.error != null) {
					throw response.error;
				}
				return response.result;
			});
	}

	function callInternal(request :RequestDef) :Promise<ResponseDef>
	{
		var deferred = new Deferred<ResponseDef>();
		var promise = deferred.promise();

		_promises[request.id] = {request:request, deferred:deferred};

		var requestString = Json.stringify(request);

		getConnection()
			.then(function(ws :WebSocketConnection) {
				ws.send(requestString);
			});

		return promise;
	}

	function get_ws() :WebSocketConnection
	{
		return _ws;
	}

	var _url :String;
	var _idCount :Int = 0;
	var _ws :WebSocketConnection;
	var _promises :Map<String, {request: RequestDef, deferred:Deferred<ResponseDef>}>;
}
