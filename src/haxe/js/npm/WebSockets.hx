package js.npm;

import js.Node;
import js.node.http.Server;

import js.node.events.EventEmitter;

typedef WebSocketMessage = {
    var type :String;
    @:optional
    var utf8Data :String;
    @:optional
    var binaryData :Dynamic;
}

typedef WebSocketClientConfig = {
    @:optional
    var webSocketVersion :Int;
    @:optional
    var closeTimeout :Int;
    //More not added yet, see:
    //https://github.com/Worlize/WebSocket-Node/wiki/Documentation
}

extern class WebSocketClient extends EventEmitter {
    public function new(?clientConfig :WebSocketClientConfig):Void;
    public function connect(requestUrl :String, ?requestedProtocols :Array<String>, ?origin :String):Void;
}

typedef WebSocketConnection = { >EventEmitter,
    var closeDescription :String;
    var closeReasonCode :Int;
    var socket :Dynamic;
    var protocol :String;
    var extensions :String;
    var remoteAddress :String;
    var webSocketVersion :String;
    var connected :Bool;
    function close() :Void;
    function drop(?reasonCode :Int, ?description :String) :Void;
    function sendUTF(data :String) :Void;
    function sendBytes(data :Dynamic) :Void;
    function send(data :Dynamic) :Void;
    function ping(data :Dynamic) :Void;
    function pong(data :Dynamic) :Void;
    function sendFrame(webSocketFrame :Dynamic) :Void;
}

typedef WebSocketRequest = { > EventEmitter,
    var httpRequest :String;
    var host :String;
    var resource :String;
    var resourceURL :String;
    var remoteAddress :String;
    var webSocketVersion :Float;
    var origin :String;
    var requestedExtensions :Array<Dynamic>;
    var requestedProtocols :Array<String>;
    function accept(acceptedProtocol :String, allowedOrigin :String) :WebSocketConnection;
    function reject(?httpStatus :Int, ?reason :String) :Void;
}

typedef WebSocketServerConfig = {
    var httpServer :Server;
    @:optional
    var autoAcceptConnections :Bool;
}

@:native("server")
@:jsRequire('ws', 'server')
extern class WebSocketServer extends EventEmitter
{
    public function new(?serverConfig:WebSocketServerConfig):Void;
    public function mount(config :WebSocketServerConfig) :Void;
    public function unmount() :Void;
    public function closeAllConnections() :Void;
    public function shutDown() :Void;
    public var connections :Array<WebSocketConnection>;
}