package t9.websockets;
/**
 * A wrapper around a websocket that reconnects if disconnected.
 * Flaky connections are part of the mobile world.
 */

import haxe.Timer;

import t9.remoting.jsonrpc.Promise;

#if nodejs
	#if !macro
		import js.Node;
		import js.npm.Ws;
	#end
#elseif js
	import js.html.WebSocket;
#end

#if promhx
// import promhx.Promise;
import promhx.Deferred;
#end

enum ReconnectType {
	None;//Acts like a regular websocket. No logic for handling reconnects.
	Repeat(intervalMilliseconds :Int);
	Decay(intervalMilliseconds :Int, intervalMultipler :Float);
}

/**
 * This will reconnect if dropped.
 * TODO: decaying reconnect time, and optional fallback urls.
 */
class WebSocketConnection
{
	public var url (get, null) :String;

	public function setKeepAliveMilliseconds(ms :Int) :WebSocketConnection
	{
		_keepAliveMilliseconds = ms;
		return this;
	}

	public function setReconnectionType(reconnectType :ReconnectType) :WebSocketConnection
	{
		_reconnectType = reconnectType;
		return this;
	}

	/**
	 *
	 */
	public function new(url :String)
	{
		_onDispose = [];
		_onerror = [];
		_onopen = [];
		_onmessage = [];
		_onclose = [];
		_url = url;
		_keepAliveMilliseconds = 25000;
		setReconnectionType(Repeat(500));
		_reconnectAttempts = 0;
		_disposed = false;
		connect();
	}

	public function registerOnError(onError :Dynamic->Void) :{dispose:Void->Void}
	{
		_onerror.push(onError);
		var index = _onerror.length - 1;
		return {dispose:function() {
			_onerror[index] = null;
		}};
	}

	public function registerOnOpen(onOpen :Void->Void) :{dispose:Void->Void}
	{
		_onopen.push(onOpen);
		var index = _onopen.length - 1;
		var disposable = {dispose:function() {
			_onopen[index] = null;
		}};

		//If the websocket is already open, call the callback on the next tick
		haxe.Timer.delay(function() {
			if (_socket != null && _socket.readyState == js.html.WebSocket.OPEN) {
				if (!_disposed) {
					onOpen();
				}
			}
		}, 0);
		return disposable;
	}

#if nodejs
	public function registerOnMessage(onMessage :Dynamic->?ReceiveFlags->Void) :{dispose:Void->Void}
#else
	public function registerOnMessage(onMessage :Dynamic->Void) :{dispose:Void->Void}
#end
	{
		_onmessage.push(onMessage);
		var index = _onmessage.length - 1;
		return {dispose:function() {
			_onmessage[index] = null;
		}};
	}

	public function registerOnClose(onClose :Dynamic->Void) :{dispose:Void->Void}
	{
		_onclose.push(onClose);
		var index = _onclose.length - 1;
		return {dispose:function() {
			_onclose[index] = null;
		}};
	}

#if nodejs
	public function send(data : String)
#else
	public function send(data :String)
#end
	{
		if (_socket != null && _socket.readyState == 1) {
			_socket.send(data);
		} else {
			throw "Cannot send message, websocket not ready";
		}
	}

	public function close()
	{
		dispose();
	}

	public function dispose()
	{
		_disposed = true;
		_onerror = null;
		_onopen = null;
		_onmessage = null;
		_onclose = null;
		disconnect();
	}

#if promhx
	public function getReady() :Promise<WebSocketConnection>
	{
		if (_socket != null && _socket.readyState == WebSocket.OPEN) {
	#if (promise == "js.npm.bluebird.Bluebird")
		return Promise.resolve(this);
	#else
		return Promise.promise(this);
	#end
		} else {

	#if (promise == "js.npm.bluebird.Bluebird")
			return new Promise(function(resolve, reject) {
				var disposable = null;
	            var whenReady = function() {
	                disposable.dispose();
	                resolve(this);
	            }
	            disposable = registerOnOpen(whenReady);
			});
	#else
			var deferred = new Deferred();
            var promise = deferred.promise();
            var disposable = null;
            var whenReady = function() {
                disposable.dispose();
                deferred.resolve(this);
            }
            disposable = registerOnOpen(whenReady);
            return promise;
	#end
        }
	}
#end

	public function connect()
	{
		_isDisconnected = false;
		#if nodejs
			_socket = new WebSocket(this._url);
		#else
			untyped __js__('var WebSocket = WebSocket || window.WebSocket || window.MozWebSocket');
			_socket = untyped __js__('new WebSocket(this._url)');
		#end

		_socket.onerror = onError;
		_socket.onopen = onOpen;
		_socket.onmessage = cast onMessage;
		_socket.onclose = onClose;
	}

	public function disconnect()
	{
		_isDisconnected = true;
		if (_keepAliveTimer != null) {
			_keepAliveTimer.stop();
			_keepAliveTimer = null;
		}
		if (_socket != null) {
			_socket.close();
			_socket = null;
		}
	}

	function onOpen()
	{
		var i = 0;
		while (_onopen != null && i < _onopen.length) {
			if (_onopen[i] != null) {
				_onopen[i]();
				i++;
			} else {
				_onopen.splice(i, 1);
			}
		}
		_reconnectAttempts = 0;
		restartTimeoutTimer();
	}

	function onError(event :Dynamic)
	{
		var i = 0;
		while (_onerror != null && i < _onerror.length) {
			if (_onerror[i] != null) {
				_onerror[i](event);
				i++;
			} else {
				_onerror.splice(i, 1);
			}
		}
	}

	function onMessage(event :{data:Dynamic, type:String})
	{
		var i = 0;
		while (_onmessage != null && i < _onmessage.length) {
			if (_onmessage[i] != null) {
				try {
#if nodejs
					_onmessage[i](event.data, null);
#else
					_onmessage[i](event);
#end
				} catch (e :Dynamic) {
					trace('Error processing event=${haxe.Json.stringify(event)} error=${e}');
				}
				i++;
			} else {
				_onmessage.splice(i, 1);
			}
		}
	}

	// function onClose(event)
    function onClose(code :Int, message :String)
	{
		if (_keepAliveTimer != null) {
			_keepAliveTimer.stop();
			_keepAliveTimer = null;
		}
		var i = 0;
		while (_onclose != null && i < _onclose.length) {
			if (_onclose[i] != null) {
				// _onclose[i](event);
                _onclose[i](null);
				i++;
			} else {
				_onclose.splice(i, 1);
			}
		}
		if (_disposed) {
			if (_socket != null) {
				_socket.onerror = null;
				_socket.onopen = null;
				_socket.onmessage = null;
				_socket.onclose = null;
			}
		} else {
			if (!_isDisconnected) {
				var reconnectInterval = 0;
				switch(_reconnectType) {
					case None:
						trace("No reconnects because ReconnectType==None");
					case Repeat(intervalMilliseconds):
						reconnectInterval = intervalMilliseconds;
					case Decay(intervalMilliseconds, intervalMultipler):
						reconnectInterval = Std.int(intervalMilliseconds * (intervalMultipler * (_reconnectAttempts + 1)));
				}
				if (reconnectInterval > 0) {
					haxe.Timer.delay(
						function() {
							if (!_disposed && !_isDisconnected) {
								_reconnectAttempts++;
								connect();
							}
						}, reconnectInterval);
				}
			}
		}
		_socket = null;
	}

	function restartTimeoutTimer()
	{
		if (_keepAliveTimer != null) {
			_keepAliveTimer.stop();
			_keepAliveTimer = null;
		}
		_keepAliveTimer = new Timer(_keepAliveMilliseconds);
		_keepAliveTimer.run = function() {
			if (_socket != null && _socket.readyState == 1) {
				#if nodejs
					_socket.ping("keep_alive");
				#else
					_socket.send("keep_alive");
				#end
			}
		}
	}

	inline function get_url() :String
	{
		return _url;
	}

	var _socket :WebSocket;
	var _url :String;
	var _reconnectType :ReconnectType;
	var _keepAliveMilliseconds :Int;
	var _keepAliveTimer :Timer;
	var _reconnectAttempts :Int;

	var _onerror :Array<Dynamic->Void>;
	var _onopen :Array<Void->Void>;
#if nodejs
    var _onmessage :Array<Dynamic->?ReceiveFlags->Void>;
#else
	var _onmessage :Array<Dynamic->Void>;
#end
    var _onclose :Array<Null<Dynamic>->Void>;
	var _disposed :Bool;
	var _isDisconnected :Bool;
	var _onDispose :Array<Void->Void>;
}