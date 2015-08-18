package t9.remoting.jsonrpc;

import haxe.remoting.JsonRpc;
import haxe.Json;

import promhx.Promise;
import promhx.Deferred;
import promhx.Stream;

import t9.websockets.WebSocketConnection;

typedef IncomingObj<T> = {>RequestDef,
	@:optional var sendResponse :T->Void;
	@:optional var sendError :ResponseError->Void;
}

class JsonRpcConnectionWebSocket
	implements JsonRpcConnection
{
	public static function urlConnect(url :String)
	{
		return new JsonRpcConnectionWebSocket(url);
	}

	public var incoming (default, null) :Stream<IncomingObj<Dynamic>>;

	public var ws (get, null):WebSocketConnection;

	public function new(url)
	{
		_url = url;
		_promises = new Map();
		_ws = new WebSocketConnection(_url);
		_ws.registerOnMessage(onMessage);

		_deferredIncomingMessages = new Deferred();
		incoming = _deferredIncomingMessages.stream();
	}

	function handleIncomingMessage(message :RequestDef)
	{
		Log.info('handleIncomingMessage');
		var incoming :IncomingObj<Dynamic> = cast message;
		if (message.id != null) {
			incoming.sendResponse = function(val :Dynamic) {
				var response :ResponseDefSuccess<Dynamic> = {id:message.id, jsonrpc:'2.0', result:val};
				var responseString = Json.stringify(response);
				getConnection()
					.then(function(ws :WebSocketConnection) {
						ws.send(responseString);
					});
			};
			incoming.sendError = function(err :ResponseError) {
				var responseErrorDef :ResponseDefError = {id:message.id, jsonrpc:'2.0', error:err};
				var errorString = Json.stringify(responseErrorDef);
				getConnection()
					.then(function(ws :WebSocketConnection) {
						ws.send(errorString);
					});
			};
		}
		_deferredIncomingMessages.resolve(incoming);
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
				handleIncomingMessage(json);
				// Log.error('Cannot yet handle server sending json-rpc requests:"$data"');
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

	public function request(method :String, ?params :Dynamic) :Promise<Dynamic>
	{
		var request :RequestDef = {
			id: (++_idCount) + '',
			method: method,
			params: params,
			jsonrpc: "2.0"
		};
		return callRequestInternal(request)
			.then(function(response: ResponseDef) {
				if (response.error != null) {
					throw response.error;
				}
				return response.result;
			});
	}

	public function notify(method :String, ?params :Dynamic) :Promise<Bool>
	{
		var request :RequestDef = {
			method: method,
			params: params,
			jsonrpc: "2.0"
		};
		return callNotifyInternal(request);
	}

	function callRequestInternal(request :RequestDef) :Promise<ResponseDef>
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

	function callNotifyInternal(request :RequestDef) :Promise<Bool>
	{
		var deferred = new Deferred<Bool>();
		var promise = deferred.promise();

		var requestString = Json.stringify(request);

		getConnection()
			.then(function(ws :WebSocketConnection) {
				ws.send(requestString);
				deferred.resolve(true);
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
	var _deferredIncomingMessages = new Deferred<IncomingObj<Dynamic>>();
}
